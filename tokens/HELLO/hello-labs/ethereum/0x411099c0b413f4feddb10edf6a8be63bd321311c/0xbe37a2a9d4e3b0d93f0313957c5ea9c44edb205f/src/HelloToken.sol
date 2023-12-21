// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

///@notice The owner will always be a multisig wallet.

/* -------------------------------------------------------------------------- */
/*                                   errors                                   */
/* -------------------------------------------------------------------------- */
error Blacklisted();
error ZeroAddress();

/* -------------------------------------------------------------------------- */
/*                                 HelloToken                                 */
/* -------------------------------------------------------------------------- */
/**
 * @title Contract for the ERC20 HelloToken on chains other than the mainnet (the chain with main dex LP)
 * @notice The full supply of tokens are minted to the deployer on deploy, and should be transferred to the bridge on this chain.
 * @notice Assumptions:
 *  - The bridge contract is the only entry point for bridged tokens from other chains
 *  - Tokens getting bridge to the chain for which this contract resides in must first be deposited in the
 *    bridge contract on the source chain
 * @author 0xSimon
 */
contract Hello is Initializable, ERC20Upgradeable, OwnableUpgradeable {
    /* -------------------------------------------------------------------------- */
    /*                                   events                                   */
    /* -------------------------------------------------------------------------- */
    event BlacklistedChanged(address wallet, bool status);
    event OnRescueToken(address tokenAddress, uint256 tokens);
    event OnClearStuckBalance(uint256 amountPercentage, address adr);

    /* -------------------------------------------------------------------------- */
    /*                                   states                                   */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice A mapping that stores blacklisted addresses
     */
    mapping(address => bool) public blacklisted;

    /* -------------------------------------------------------------------------- */
    /*                                 constructor                                */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice Deploys the contract and mints the entire supply to the deployer
     * @dev `tx.origin` is used instead of `msg.sender` just in case this contract get deployed via a contract
     *  @custom:oz-upgrades-unsafe-allow constructor

     */
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC20_init("Hello", "HELLO");
        __Ownable_init();
        _mint(tx.origin, 1e9 ether);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  overrides                                 */
    /* -------------------------------------------------------------------------- */
    /**
     * @dev Override the _transfer function to support blacklisting
     */
    function _transfer(address sender, address to, uint256 amount) internal override {
        if (blacklisted[sender] || blacklisted[to]) {
            revert Blacklisted();
        }

        super._transfer(sender, to, amount);
    }

    /* -------------------------------------------------------------------------- */
    /*                                   owners                                   */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice Owner only - Updates the blacklist mapping
     * @param _wallet the address to update the blacklist status of
     * @param status whether the address is blacklisted
     */
    function setBlacklisted(address _wallet, bool status) external onlyOwner {
        // check zero
        if (_wallet == address(0)) {
            revert ZeroAddress();
        }

        // update
        blacklisted[_wallet] = status;

        // emit
        emit BlacklistedChanged(_wallet, status);
    }

    function rescueToken(address tokenAddress, uint256 tokens) external onlyOwner {
        IERC20(tokenAddress).transfer(msg.sender, tokens);
        emit OnRescueToken(tokenAddress, tokens);
    }

    function clearStuckBalance(address adr) external onlyOwner {
        if (adr == address(0)) revert ZeroAddress();
        uint256 __balance = address(this).balance;
        (bool success,) = payable(adr).call{value: __balance}("");
        require(success);
        emit OnClearStuckBalance(__balance, adr);
    }
}
