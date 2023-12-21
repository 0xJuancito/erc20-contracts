pragma solidity ^0.5.8;

import './TestGreeter_v0.sol';

contract TestGreeter_v1 is TestGreeter_v0("Hi, World!") {

    function farewell() public view returns (string memory) {
        return "Good bye!";
    }
}
