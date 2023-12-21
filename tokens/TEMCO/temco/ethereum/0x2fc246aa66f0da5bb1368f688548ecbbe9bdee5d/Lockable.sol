pragma solidity ^0.4.24;


import "./Ownable.sol";


/**
 * @title Lockable
 * @dev lock up token transfer during duration. This helps lock up private and pre-sale investor cannot sell token certain period.
 * @author Geunil(Brian) Lee
 */
contract Lockable is Ownable {
  
    /**
    * @dev hold lock up address and duration
    */
    mapping(address => uint256) public lockedUp;
  
    uint public nowTime;
    
    constructor () public {
        nowTime = now;        
    }

    /**
    * @dev lock up by pass when duration is passed or not exist on lockedUp mapping.
    */
    modifier whenNotLockedUp() {
        require(lockedUp[msg.sender] < now || lockedUp[msg.sender] == 0 );
        _;
    }


    /**
    * @dev lock up status
    * @return true - no lock up. false - locked up 
    */
    function nolockedUp(address sender) public view returns (bool){
        if(lockedUp[sender] < now || lockedUp[sender] == 0){
            return true; 
        }
        return false;                
    }
  
    /**
    * @dev add lock up investor to mapping
    * @param _investor lock up address
    * @param _duration lock up period. unit is days
    */
    function addLockUp(address _investor, uint _duration ) onlyOwner public {
        require(_investor != address(0) && _duration > 0);
        lockedUp[_investor] = now + _duration * 1 days; 
    }
    
    /**
    * @dev remove lock up address from mapping
    * @param _investor lock up address to be removed from mapping
    */
    function removeLockUp(address _investor ) onlyOwner public {
        require(_investor != address(0));
        delete lockedUp[_investor]; 
    }
  
  
}