// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
// import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {UnrenounceableOwnable2Step} from "./UnrenounceableOwnable2Step.sol";

/**
 * @title Blacklistable Contract
 * @dev This contract provides functionality to manage a blacklist of addresses and control access to blacklisting operations.
 */

// contract Blacklistable is Ownable {
contract Blacklistable is UnrenounceableOwnable2Step {
    mapping(address => bool) public isBlacklisted;
    address public blacklister;

    event AddedBlackList(address indexed evilUser);
    event RemovedBlackList(address indexed clearedUser);
    event BlacklisterChanged(address indexed newBlacklister);

    /**
     * @dev Initializes the contract with the deployer's address as the initial blacklister.
     */
    constructor() {
        blacklister = msg.sender;
    }

    /**
     * @dev Reverts if called by any account other than the blacklister
     */
    modifier onlyBlacklister() {
        require(
            msg.sender == blacklister,
            "Blacklistable: caller is not the blacklister"
        );
        _;
    }

    /**
     * @dev Throws if argument account is blacklisted
     * @param _account The address to check
     */
    modifier notBlacklisted(address _account) {
        require(
            !isBlacklisted[_account],
            "Blacklistable: account is blacklisted"
        );
        _;
    }

    /**
     * @dev Blacklists an address.
     * @param _evilUser Address to blacklist.
     * Emits `AddedBlackList` event.
     */
    function addBlacklist(address _evilUser) external onlyBlacklister {
        isBlacklisted[_evilUser] = true;
        emit AddedBlackList(_evilUser);
    }

    /**
     * @dev Removes an address from the blacklist.
     * @param _clearedUser Address to unblacklist.
     * Emits `RemovedBlackList` event.
     */
    function removeBlackList(address _clearedUser) external onlyBlacklister {
        isBlacklisted[_clearedUser] = false;
        emit RemovedBlackList(_clearedUser);
    }

    /**
     * @dev Updates the blacklister address. Only the owner can change the blacklister.
     * @param _newBlacklister New blacklister's address.
     * Requires non-zero address.
     * Emits `BlacklisterChanged` event.
     */
    function updateBlacklister(address _newBlacklister) external onlyOwner {
        require(
            _newBlacklister != address(0),
            "Blacklistable: new blacklister is the zero address"
        );
        blacklister = _newBlacklister;
        emit BlacklisterChanged(blacklister);
    }

    /**
     * @dev Checks if an address is blacklisted.
     */
    function getBlackListStatus(address _maker) public view returns (bool) {
        return isBlacklisted[_maker];
    }
}
