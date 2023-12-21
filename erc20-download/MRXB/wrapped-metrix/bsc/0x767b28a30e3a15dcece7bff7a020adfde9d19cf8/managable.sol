// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

import "./ownable.sol";

/**
 * @title Managable
 * @dev Set & change managers permission
 */
contract Managable is Ownable {
    mapping(address => bool) private managers;

    // event for EVM logging
    event ManagersChanged(address indexed manager, bool allowed);

    // modifier to check if caller is manager
    modifier isManager() {
        // If the first argument of 'require' evaluates to 'false', execution terminates and all
        // changes to the state and to Ether balances are reverted.
        // This used to consume all gas in old EVM versions, but not anymore.
        // It is often a good idea to use 'require' to check if functions are called correctly.
        // As a second argument, you can also provide an explanation about what went wrong.
        require(
            managers[msg.sender] == true || this.getOwner() == msg.sender,
            "Caller is not manager"
        );
        _;
    }

    /**
     * @dev Change manager
     * @param manager address of manager
     */
    function setManager(address manager, bool allowed) public isOwner {
        managers[manager] = allowed;
        emit ManagersChanged(manager, allowed);
    }

    function addressIsAManager(address addr) public view returns (bool) {
        return managers[addr] == true || this.getOwner() == addr;
    }
}
