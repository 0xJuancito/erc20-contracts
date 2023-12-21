pragma solidity 0.5.8;

import "./Pauser.sol";

contract Minter is Pauser {
    address public minter = address(0);

    modifier onlyMinter() {
        require(msg.sender == minter, "the sender is not the minter");
        _;
    }
}