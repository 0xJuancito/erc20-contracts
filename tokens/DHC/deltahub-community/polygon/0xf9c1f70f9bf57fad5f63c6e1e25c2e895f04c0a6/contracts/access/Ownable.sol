// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/utils/Context.sol";

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function initOwner(address sender_) public {
        require(owner() == address(0), "OWNER_ALREADY_INITIALIZED");
        _owner = sender_;
        emit OwnershipTransferred(address(0), sender_);
    }

    function transferOwnership(address newOwner_) public onlyOwner {
        require(newOwner_ != address(0), "INVALID_ADDRESS");
        emit OwnershipTransferred(_owner, newOwner_);
        _owner = newOwner_;
    }

    modifier onlyOwner() {
        require(_msgSender() == owner(), "CALLER_NOT_AUTHORIZED");
        _;
    }
}
