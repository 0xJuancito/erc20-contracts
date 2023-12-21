pragma solidity ^0.4.24;


/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 * based on https://https://github.com/OpenZeppelin/zeppelin-solidity. modified to have multiple ownership.
 * @author Geunil(Brian) Lee
 */
contract Ownable {
  
    /**
    * Ownership can be owned by multiple owner. Useful when have multiple contract to communicate  each other
    **/
    mapping (address => bool) public owner;
  
    event OwnershipAdded(address newOwner);
    event OwnershipRemoved(address noOwner);    

    /**
    * @dev The Ownable constructor sets the original `owner` of the contract to the sender
    * account.
    */
    constructor () public {
        owner[msg.sender] = true;        
    }

    /**
    * @dev Throws if called by any account other than the owner.
    */
    modifier onlyOwner() {
        require(owner[msg.sender] == true);
        _;
    }

    /**
    * @dev Add ownership
    * @param _newOwner add address to the ownership
    */
    function addOwnership(address _newOwner) public onlyOwner {
        require(_newOwner != address(0));
        owner[_newOwner] = true;
        emit OwnershipAdded(_newOwner);
    }
  
    /**
    * @dev Remove ownership
    * @param _ownership remove ownership
    */
    function removeOwner(address _ownership) public onlyOwner{
        require(_ownership != address(0));
        // owner cannot remove ownerhip itself
        require(msg.sender != _ownership);
        delete owner[_ownership];
        emit OwnershipRemoved(_ownership);
    }

}