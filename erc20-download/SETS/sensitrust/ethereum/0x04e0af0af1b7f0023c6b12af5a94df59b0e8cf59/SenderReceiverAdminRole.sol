pragma solidity ^0.5.0;

/*
The MIT License (MIT)

Copyright (c) 2019-2020 Sensitrust Limited

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import './Roles.sol';

/**
 * @title SenderReceiverAdminRole
 * @dev SenderReceiverAdmins can send or receive tokens, independently on transferability of tokens.
 */
contract SenderReceiverAdminRole 
{
    using Roles for Roles.Role;

    // Events for receiver/sender admins
    event SenderAdminAdded(address indexed account);
    event SenderAdminRemoved(address indexed account);
    event ReceiverAdminAdded(address indexed account);
    event ReceiverAdminRemoved(address indexed account);

    // Set of addresses owning the admin role
    Roles.Role private _senderAdmins;
    Roles.Role private _receiverAdmins;

    // Constructor
    constructor () internal {
        _addSenderAdmin(msg.sender);
        _addReceiverAdmin(msg.sender);
    }

    // Functions to manage the Sender Admin Role
    // ----------------------------------------------------------------------------
    modifier onlySenderAdmin() {
        require(isSenderAdmin(msg.sender), "This operation can be performed by Sender Admins only");
        _;
    }

    function isSenderAdmin(address account) public view returns (bool) {
        return _senderAdmins.has(account);
    }

    function addSenderAdmin(address account) public onlySenderAdmin {
        _addSenderAdmin(account);
    }

    function renounceSenderAdmin() public onlySenderAdmin {
        _removeSenderAdmin(msg.sender);
    }

    function _addSenderAdmin(address account) internal {
        _senderAdmins.add(account);
        emit SenderAdminAdded(account);
    }

    function _removeSenderAdmin(address account) internal {
        _senderAdmins.remove(account);
        emit SenderAdminRemoved(account);
    }
    // ----------------------------------------------------------------------------
    
    
    // Functions to manage the Receiver Admin Role
    // ----------------------------------------------------------------------------
    modifier onlyReceiverAdmin() {
        require(isReceiverAdmin(msg.sender), "This operation can be performed by Receiver Admins only");
        _;
    }

    function isReceiverAdmin(address account) public view returns (bool) {
        return _receiverAdmins.has(account);
    }

    function addReceiverAdmin(address account) public onlyReceiverAdmin {
        _addReceiverAdmin(account);
    }

    function renounceReceiverAdmin() public onlyReceiverAdmin {
        _removeReceiverAdmin(msg.sender);
    }

    function _addReceiverAdmin(address account) internal {
        _receiverAdmins.add(account);
        emit ReceiverAdminAdded(account);
    }

    function _removeReceiverAdmin(address account) internal {
        _receiverAdmins.remove(account);
        emit ReceiverAdminRemoved(account);
    }
    // ----------------------------------------------------------------------------
}
