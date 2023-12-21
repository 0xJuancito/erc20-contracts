pragma solidity ^0.4.23;

import "./Ownable.sol";
import "./StandardToken.sol";


/**
 * @title TransferableToken
 */
contract TransferableToken is StandardToken, Ownable {
    bool public isLocked;

    mapping (address => bool) public transferableAddresses;
    mapping (address => bool) public receivableAddresses;

    constructor() public {
        isLocked = true;
    }

    event Unlock();
    event TransferableAddressAdded(address indexed addr);
    event TransferableAddressRemoved(address indexed addr);
    event ReceivableAddressAdded(address indexed addr);
    event ReceivableAddressRemoved(address indexed addr);

    function unlock() public onlyOwner {
        isLocked = false;
        emit Unlock();
    }

    function isTransferable(address addr) public view returns(bool) {
        return !isLocked || transferableAddresses[addr];
    }

    function isReceivable(address addr) public view returns(bool) {
        return !isLocked || receivableAddresses[addr];
    }

    function addTransferableAddresses(address[] addrs) public onlyOwner returns(bool success) {
        for (uint256 i = 0; i < addrs.length; i++) {
            if (addTransferableAddress(addrs[i])) {
                success = true;
            }
        }
    }

    function addReceivableAddresses(address[] addrs) public onlyOwner returns(bool success) {
        for (uint256 i = 0; i < addrs.length; i++) {
            if (addReceivableAddress(addrs[i])) {
                success = true;
            }
        }
    }

    function addTransferableAddress(address addr) public onlyOwner returns(bool success) {
        if (!transferableAddresses[addr]) {
            transferableAddresses[addr] = true;
            emit TransferableAddressAdded(addr);
            success = true;
        }
    }

    function addReceivableAddress(address addr) public onlyOwner returns(bool success) {
        if (!receivableAddresses[addr]) {
            receivableAddresses[addr] = true;
            emit ReceivableAddressAdded(addr);
            success = true;
        }
    }

    function removeTransferableAddresses(address[] addrs) public onlyOwner returns(bool success) {
        for (uint256 i = 0; i < addrs.length; i++) {
            if (removeTransferableAddress(addrs[i])) {
                success = true;
            }
        }
    }

    function removeReceivableAddresses(address[] addrs) public onlyOwner returns(bool success) {
        for (uint256 i = 0; i < addrs.length; i++) {
            if (removeReceivableAddress(addrs[i])) {
                success = true;
            }
        }
    }

    function removeTransferableAddress(address addr) public onlyOwner returns(bool success) {
        if (transferableAddresses[addr]) {
            transferableAddresses[addr] = false;
            emit TransferableAddressRemoved(addr);
            success = true;
        }
    }

    function removeReceivableAddress(address addr) public onlyOwner returns(bool success) {
        if (receivableAddresses[addr]) {
            receivableAddresses[addr] = false;
            emit ReceivableAddressRemoved(addr);
            success = true;
        }
    }

    /**
    */
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(isTransferable(_from) || isReceivable(_to), "From address not transferable and To address not receivable");
        return super.transferFrom(_from, _to, _value);
    }

    /**
    */
    function transfer(address _to, uint256 _value) public returns (bool) {
        require(isTransferable(msg.sender) || isReceivable(_to), "Sender not transferable and To address not receivable");
        return super.transfer(_to, _value);
    }
}
