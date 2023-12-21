// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Freezable is Ownable {
    bool public emergencyFreeze;
    mapping(address => bool) public frozen;

    event LogFreezed(address indexed target, bool freezeStatus);
    event LogEmergencyFreezed(bool emergencyFreezeStatus);

    modifier unfreezed(address _account) {
        require(!frozen[_account], "Account is freezed");
        _;
    }

    modifier noEmergencyFreeze() {
        require(!emergencyFreeze, "Contract is emergency freezed");
        _;
    }

   
    function freezeAccount(address _target, bool _freeze) public onlyOwner {
        require(_target != address(0), "Zero address not allowed");
        frozen[_target] = _freeze;
        emit LogFreezed(_target, _freeze);
    }

 
    function emergencyFreezeAllAccounts(bool _freeze) public onlyOwner {
        emergencyFreeze = _freeze;
        emit LogEmergencyFreezed(_freeze);
    }
}