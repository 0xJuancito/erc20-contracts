// SPDX-License-Identifier: -- 💰 --

pragma solidity ^0.7.3;

contract Ownable {

    address public owner;

    event ownershipChanged(
        address indexed _invoker,
        address indexed _newOwner
    );

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            'Ownable: must be the owner'
        );
        _;
    }

    function changeOwner(
        address _newOwner
    )
        external
        onlyOwner
        returns (bool)
    {
        
        require(
            _newOwner != address(0),
            'Ownable: new owner must not be the blackhole address'
        );
        
        owner = _newOwner;

        emit ownershipChanged(
            msg.sender,
            _newOwner
        );

        return true;
    }
}