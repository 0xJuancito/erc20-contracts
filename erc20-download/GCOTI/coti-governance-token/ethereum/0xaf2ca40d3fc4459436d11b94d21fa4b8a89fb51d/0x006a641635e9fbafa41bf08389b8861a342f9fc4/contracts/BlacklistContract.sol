// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/**
 * @title Blacklistable Token
 * @dev Allows accounts to be blacklisted by a "owner"
*/
contract Blacklistable {

    mapping(address => bool) public blacklisted;

    event Blacklisted(address indexed _account);
    event UnBlacklisted(address indexed _account);

    /**
     * @dev Throws if argument account is blacklisted
     * @param _account The address to check
    */
    modifier notBlacklisted(address _account) {
        require(blacklisted[_account] == false);
        _;
    }

    /**
     * @dev Checks if account is blacklisted
     * @param _account The address to check
    */
    function isBlacklisted(address _account) public view returns (bool) {
        return blacklisted[_account];
    }

    /**
     * @dev Adds account to blacklist
     * @param _account The address to blacklist
    */
    function _blacklist(address _account) internal virtual {
        blacklisted[_account] = true;
        emit Blacklisted(_account);
    }

    /**
     * @dev Removes account from blacklist
     * @param _account The address to remove from the blacklist
    */
    function _unBlacklist(address _account) internal virtual {
        blacklisted[_account] = false;
        emit UnBlacklisted(_account);
    }
}
