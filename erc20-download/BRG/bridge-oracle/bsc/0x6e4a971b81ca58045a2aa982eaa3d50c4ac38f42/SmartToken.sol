// SPDX-License-Identifier: MIT
pragma solidity 0.8.8;

import "./StandardToken.sol";


abstract contract IBEP677 is IBEP20 {
    function transferAndCall(address receiver, uint value, bytes memory data) public virtual returns (bool success);
    event Transfer(address indexed from, address indexed to, uint256 value, bytes data);
}

abstract contract BEP677Receiver {
    function onTokenTransfer(address _sender, uint _value, bytes memory _data) public virtual;
}

abstract contract SmartToken is IBEP677, StandardToken {
    
    function transferAndCall(address _to, uint256 _value, bytes memory _data) public override validRecipient(_to) returns(bool success) {
        _transfer(msg.sender, _to, _value);
        emit Transfer(msg.sender, _to, _value, _data);
        if (isContract(_to)) {
            contractFallback(_to, _value, _data);
        }
        return true;
    }

    function contractFallback(address _to, uint _value, bytes memory _data) private {
        BEP677Receiver receiver = BEP677Receiver(_to);
        receiver.onTokenTransfer(msg.sender, _value, _data);
    }

    function isContract(address _addr) private view returns (bool hasCode) {
    uint length;
    assembly { length := extcodesize(_addr) }
    return length > 0;
    }
    
}