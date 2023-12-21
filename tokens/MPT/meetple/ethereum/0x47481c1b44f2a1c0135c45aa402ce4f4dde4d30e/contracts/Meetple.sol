// SPDX-License-Identifier: MIT
pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract MeetPleToken is ERC20,Ownable{
    
     struct Entry{
        uint index;
        bool value;
    }
    
    enum TransferRole {ALL_PASUE,WHITELIST,NORMAL}
    TransferRole transferRole;
    mapping (address => Entry) whitelist;
    address[] whitelistKeys;
    mapping (address => Entry) blacklist;
    address[] blacklistKeys;
    
    //mapping (address => uint256) public airDropHistory;
    event AirDrop(address _receiver, uint256 _amount);

    
    constructor () public ERC20("MeetPle","MPT"){
        //uint256 initialSupply = 3000000000;
        uint8 DECIMALS = 18;
        uint256 INITIAL_SUPPLY = 3000000000 * (10 ** uint256(DECIMALS));
        _mint(msg.sender, INITIAL_SUPPLY);
        transferRole = TransferRole.WHITELIST;
    }
    
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override onlyOwner returns (bool) {
        super.transferFrom(sender,recipient,amount);
    }
    
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual override onlyOwner returns (bool) {
        super.decreaseAllowance(spender,subtractedValue);
    }
    function increaseAllowance(address spender, uint256 addedValue) public virtual override onlyOwner returns (bool) {
        super.increaseAllowance(spender,addedValue);
    }
    
    function allowance(address owner, address spender) public view virtual override onlyOwner returns (uint256) {
        super.allowance(owner,spender);
    }
    
    function approve(address spender, uint256 amount) public virtual override onlyOwner returns (bool) {
        super.approve(spender, amount);
    }
    
    function mint(address to, uint256 amount) public onlyOwner  {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyOwner  {
        _burn(from, amount);
    }
    
    function transfer(address to, uint256 amount) public override  returns (bool) {
        if(transferRole == TransferRole.ALL_PASUE)
        {
            revert('transfer stop');
        }else if(transferRole == TransferRole.WHITELIST){
            require(isWhiteExists(msg.sender) , "your address transfer denied");
            super.transfer(to, amount);
        }else if(transferRole == TransferRole.NORMAL){
            require(!isBlackExists(msg.sender) , "your address transfer denied");
            super.transfer(to, amount);
        }else {
            revert('transferRole type error');
        }
        
    }
    
    function dropToken(address[] memory receivers, uint256[] memory values) public onlyOwner {
        require(receivers.length != 0);
        require(receivers.length == values.length);
    
        for (uint256 i = 0; i < receivers.length; i++) {
          address receiver = receivers[i];
          uint256 amount = values[i];
    
          transfer(receiver, amount);
    
          emit AirDrop(receiver, amount);
        }
    }
    
    function ownerTransfer(address to, uint256 amount) public onlyOwner returns (bool) {
            return super.transfer(to, amount);
    }
    
    function recoverTransfer(address recoverAddress , uint256 amount) public onlyOwner returns (bool) {
        _transfer(recoverAddress,super.owner(),amount);
    }
    
    function isWhiteExists (address user) public view returns(bool){
        if(whitelist[user].value)
        {
            return true;
        }else{
            return false;
        }
    }
   
    function isBlackExists (address user) public view returns(bool){
        if(blacklist[user].value)
        {
            return true;
        }else{
            return false;
        }
   }
    

     function addWhitelistAddress (address[] memory users) public onlyOwner {
        for (uint i = 0; i < users.length; i++) {
            
            Entry storage entry = whitelist[users[i]];
            entry.value = true;
            if(entry.index > 0){ // entry exists
               continue;
            }else { // new entry
                whitelistKeys.push(users[i]);
                uint keyListIndex = whitelistKeys.length - 1;
                entry.index = keyListIndex + 1;
            }
        }
        
      
    }
    
    function delWhitelistAddress (address[] memory users) public onlyOwner {
        for (uint i = 0; i < users.length; i++) {
            Entry storage entry = whitelist[users[i]];
            require(entry.index != 0); // entry not exist
            require(entry.index <= whitelistKeys.length); // invalid index value
            
            // Move an last element of array into the vacated key slot.
            uint keyListIndex = entry.index - 1;
            uint keyListLastIndex = whitelistKeys.length - 1;
            whitelist[whitelistKeys[keyListLastIndex]].index = keyListIndex + 1;
            whitelistKeys[keyListIndex] = whitelistKeys[keyListLastIndex];
            whitelistKeys.pop();
            delete whitelist[users[i]];
        }
    }
    
    function getWhiteListAddress () public view returns(address[] memory addresses){
        return whitelistKeys;
    }
    
    function getBlackListAddress () public view returns(address[] memory addresses){
        return blacklistKeys;
    }
    
    
    function addBlacklistAddress (address[] memory users) public onlyOwner {
        for (uint i = 0; i < users.length; i++) {
            
            Entry storage entry = blacklist[users[i]];
            entry.value = true;
            if(entry.index > 0){ // entry exists
               continue;
            }else { // new entry
                blacklistKeys.push(users[i]);
                uint keyListIndex = blacklistKeys.length - 1;
                entry.index = keyListIndex + 1;
            }
        }
    }
    
    function delBlacklistAddress (address[] memory users) public onlyOwner {
        for (uint i = 0; i < users.length; i++) {
            Entry storage entry = blacklist[users[i]];
            require(entry.index != 0); // entry not exist
            require(entry.index <= blacklistKeys.length); // invalid index value
            
            // Move an last element of array into the vacated key slot.
            uint keyListIndex = entry.index - 1;
            uint keyListLastIndex = blacklistKeys.length - 1;
            blacklist[blacklistKeys[keyListLastIndex]].index = keyListIndex + 1;
            blacklistKeys[keyListIndex] = blacklistKeys[keyListLastIndex];
            blacklistKeys.pop();
            delete blacklist[users[i]];
        }
    }
    
    
  

    function setValues(uint _value) public onlyOwner{
      require(uint(TransferRole.NORMAL) >= _value);
      transferRole = TransferRole(_value);
    }

    function getValue() public view returns (uint){
      return uint(transferRole);
    }
}


  