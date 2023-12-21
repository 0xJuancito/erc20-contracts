pragma solidity ^0.8;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @dev Allows accounts to be blacklisted by an owner
*/
contract Blacklistable is Ownable {
    mapping (address => bool) internal blacklistedAccounts;

    event Blacklisted(address indexed _account);
    event UnBlacklisted(address indexed _account);

    /**
     * @dev Throws if argument account is blacklisted
     * @param _account The address to check
    */
    modifier notBlacklisted(address _account) {
        require(!blacklistedAccounts[_account], "this address blocklisted");
        _;
    }

    /**
     * @dev Checks if account is blacklisted
     * @param _account The address to check    
    */
    function isBlacklisted(address _account) public view returns (bool) {
        return blacklistedAccounts[_account];
    }

    /**
     * @dev Adds account to blacklist
     * @param _account The address to blacklist
    */
    function blacklist(address _account) public onlyOwner {
        blacklistedAccounts[_account] = true;
        emit Blacklisted(_account);
    }

    /**
     * @dev Removes account from blacklist
     * @param _account The address to remove from the blacklist
    */
    function unBlacklist(address _account) public onlyOwner {
        delete blacklistedAccounts[_account];
        emit UnBlacklisted(_account);
    }
}