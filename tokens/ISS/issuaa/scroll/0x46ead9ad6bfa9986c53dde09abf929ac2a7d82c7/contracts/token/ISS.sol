// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./oft/v1/OFT.sol";



// @dev example implementation inheriting a OFT
contract ISS is OFT {
    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint,
        uint256 _initialSupply
    ) OFT(_name, _symbol, _lzEndpoint){
       if (_initialSupply > 0){
         _mint(msg.sender, _initialSupply);
        }
    }

    

    /**
     * @notice A method that burns tokens. Can only be called by the owner.
     * @param _address Address that receives the tokens.
     *        _amount Amount to tokens to be minted in WEI.
     */
    function burn(
        address _address,
        uint256 _amount
        ) 
        external 
        onlyOwner {
        _burn(_address, _amount);
    }
}