pragma solidity ^0.5.0;

import './ERC20Detailed.sol';
import './ERC20Burnable.sol';

import './SenderReceiverAdminRole.sol';

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

contract FullERC20Token is 
    ERC20,                      // Define our token as a Standard ERC20 token
    ERC20Detailed,              // Add detailed information
    ERC20Burnable,              // Add the possibility to burn tokens
    SenderReceiverAdminRole     // Add roles and functions to manage admins for receiving and sending tokens, independently on the transferability
{
    
    // Specifies if the tokens can be transferred  
    bool private _transferable = false;
    
    
     /** Constructor
     * @param _name Extended name of the token 
     * @param _symbol Symbol representing the token
     * @param _decimals Number of decimals 
     * @param _amount Number of tokens to create (Total Supply)
     */
    constructor (string memory _name, string memory _symbol, uint8 _decimals, uint256 _amount) 
        ERC20Detailed(_name, _symbol, _decimals)    // Call the constructor of ERC20Detailed
        public 
    {
        require(_amount > 0, "The total supply must be greater than 0");
         
        // Calculate the total supply
        uint256 totalSupply = _amount.mul(10 ** uint256(_decimals));

        // Mint the corresponding amount of tokens and assign them to the conctract creator
        _mint(msg.sender, totalSupply); 
        
        // Assign the contract creator to the group of transfer admins
        _addTransferAdmin(msg.sender);
    }
    
     /** Check whether tokens can be transferred
     * @return True if tokens can be transferred, False otherwise
     */
    function isTransferrable() public view returns (bool) {
        return _transferable;
    }
    
    /** Enable the transferability of tokens */
    function enableTransfer() public onlyTransferAdmin {
        _transferable = true;
    }
    
    
    /** Add additional checks to the _transfer function (transferability)
     * @dev Transfer token for a specified addresses
     * @param from The address to transfer from.
     * @param to The address to transfer to.
     * @param value The amount to be transferred.
     */
    function _transfer(address from, address to, uint256 value) internal {
        require(isTransferrable() || isSenderAdmin(from) || isReceiverAdmin(to), "Token transfer is not enabled yet");
        super._transfer(from, to, value);
    }
    
    
    
    // Attributes and functions to manage the Transfer Admin Role
    // ----------------------------------------------------------------------------
    using Roles for Roles.Role;

    // Events for transfer admins
    event TransferAdminAdded(address indexed account);
    event TransferAdminRemoved(address indexed account);

    // Set of addresses owning the admin role
    Roles.Role private _transferAdmins;

    modifier onlyTransferAdmin() {
        require(isTransferAdmin(msg.sender), "This operation can be performed by Transfer Admins only");
        _;
    }

    function isTransferAdmin(address account) public view returns (bool) {
        return _transferAdmins.has(account);
    }

    function addTransferAdmin(address account) public onlyTransferAdmin {
        _addTransferAdmin(account);
    }

    function renounceTransferAdmin() public onlyTransferAdmin {
        _removeTransferAdmin(msg.sender);
    }

    function _addTransferAdmin(address account) internal {
        _transferAdmins.add(account);
        emit TransferAdminAdded(account);
    }

    function _removeTransferAdmin(address account) internal {
        _transferAdmins.remove(account);
        emit TransferAdminRemoved(account);
    }
    // ----------------------------------------------------------------------------
}

   
