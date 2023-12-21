// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";


///@notice The contract is a storage contract for the bridge contract.
///@notice The owner will always be a multisig wallet.

/* -------------------------------------------------------------------------- */
/*                                   errors                                   */
/* -------------------------------------------------------------------------- */
error SignerNotWithdrawSigner();
error NoAmountToWithdraw();
error CannotBridgeToUnsupportedChain();
error Paused();
error NotPaused();
error ZeroAddress();

contract HelloBridgeStore is Ownable {
    /* -------------------------------------------------------------------------- */
    /*                                   errors                                   */
    /* -------------------------------------------------------------------------- */
    error ErrUnauthorized();
    error ErrZeroAddress();

    /* -------------------------------------------------------------------------- */
    /*                                   events                                   */
    /* -------------------------------------------------------------------------- */
    event BridgeContractChanged(address bridgeContract);

    /* -------------------------------------------------------------------------- */
    /*                                   states                                   */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice A mapping that stores how much HelloToken a user has deposited to bridge to a destination chain
     * @dev Maps from userAddress -> chainID -> amount
     */
    mapping(address => mapping(uint256 => uint256)) public totalCrossChainDeposits;

    /**
     * @notice A mapping that stores how much HelloToken a user has withdrawn from a destination chain
     * @dev Maps from userAddress -> chainID -> amount
     */
    mapping(address => mapping(uint256 => uint256)) public totalCrossChainWithdrawals;

    /**
     * @notice The bridge contract associated with this storage contract.
     * This is the only contract authorized to update `totalCrossChainDeposits` & `totalCrossChainWithdrawals`
     */
    address public bridgeContract;

    /* -------------------------------------------------------------------------- */
    /*                                    owner                                   */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice Updates the bridge contract associated with this storage contract
     */
    function setBridgeContract(address b_) external onlyOwner {
        if (b_ == address(0)) {
            revert ErrZeroAddress();
        }

        bridgeContract = b_;

        emit BridgeContractChanged(b_);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  external                                  */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice Updates totalCrossChainDeposits of a user to a destination chain
     * @param address_ The address to update
     * @param chainID_ The destination chainID of the deposit
     * @param amount_ The amount of token deposited
     */
    function setTotalCrossChainDeposits(address address_, uint256 chainID_, uint256 amount_) external {
        if (msg.sender != bridgeContract) {
            revert ErrUnauthorized();
        }

        totalCrossChainDeposits[address_][chainID_] = amount_;
    }

    /**
     * @notice Updates totalCrossChainWithdrawals of a user from a source chain
     * @param address_ The address to update
     * @param chainID_ The source chainID of the withdrawal
     * @param amount_ The amount of token withdrawn
     */
    function setTotalCrossChainWithdrawals(address address_, uint256 chainID_, uint256 amount_) external {
        if (msg.sender != bridgeContract) {
            revert ErrUnauthorized();
        }

        totalCrossChainWithdrawals[address_][chainID_] = amount_;
    }
}