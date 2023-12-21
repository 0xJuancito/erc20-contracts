//SPDX-License-Identifier: MIT
pragma solidity 0.7.5;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface ITokenRecipient {
    function receiveApproval(address _from, uint256 _value, address _token, bytes calldata _extraData) external;
}

abstract contract Payable is ERC20 {
    event LogApproveAndCall(address _spender, uint256 _value);

    function approveAndCall(address _spender, uint256 _value, bytes calldata _extraData) external {
        _approve(msg.sender, _spender, _value);
        emit LogApproveAndCall(_spender, _value);
        ITokenRecipient(_spender).receiveApproval(msg.sender, _value, address(this), _extraData);
    }
}
