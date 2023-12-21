pragma solidity ^0.5.0;

contract OwnershipStorage {
    address internal _admin;

    constructor () public {
        _admin = msg.sender;
    }

    function admin() public view returns (address) {
        return _admin;
    }

    function setNewAdmin(address newAdmin) public {
        require(msg.sender == _admin);
        require(newAdmin != address(0));
        _admin = newAdmin;
    }
}