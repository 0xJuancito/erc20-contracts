// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4;

import '../libraries/SafeOwnableInterface.sol';

abstract contract Operatable is SafeOwnableInterface {

    event OperatorChanged(address Operator, bool available);
    event OperatorLocked();

    mapping(address => bool) public operators;
    bool public operatorLocked;

    modifier OperatorNotLocked {
        require(!operatorLocked, "Operator locked");
        _;
    }

    function addOperator(address _Operator) public onlyOwner OperatorNotLocked {
        require(!operators[_Operator], "already Operator");
        operators[_Operator] = true;
        emit OperatorChanged(_Operator, true);
    }

    function delOperator(address _Operator) public onlyOwner {
        require(operators[_Operator], "not a Operator");
        delete operators[_Operator];
        emit OperatorChanged(_Operator, false);
    }

    function OperatorLock() public onlyOwner {
        operatorLocked = true;
        emit OperatorLocked();
    }

    modifier onlyOperator() {
        require(operators[msg.sender], "only Operator can do this");
        _;
    }

    modifier onlyOperatorSignature(bytes32 _hash, uint8 _v, bytes32 _r, bytes32 _s) {
        address verifier = ecrecover(keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _hash)), _v, _r, _s);
        require(operators[verifier], "Operator verify failed");
        _;
    }

    modifier onlyOperatorOrOperatorSignature(bytes32 _hash, uint8 _v, bytes32 _r, bytes32 _s) {
        if (!operators[msg.sender]) {
            address verifier = ecrecover(keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _hash)), _v, _r, _s);
            require(operators[verifier], "Operator verify failed");
        }
        _;
    }
}
