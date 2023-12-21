pragma solidity 0.5.8;

import "./Common.sol";

contract Wiper is Common  {
    address public wiper = address(0);
    
    modifier onlyWiper() {
        require(msg.sender == wiper, "the sender is not the wiper");
        _;
    }

    function initializeWiper(address _account) public isNotZeroAddress(_account) {
        require(wiper == address(0), "the wiper can only be initiated once");
        wiper = _account;
    }
}