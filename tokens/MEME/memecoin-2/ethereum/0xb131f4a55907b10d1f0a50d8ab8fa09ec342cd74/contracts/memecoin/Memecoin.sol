// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Memecoin is ERC20, ERC20Permit, Ownable {
    error Unauthorized();

    event TokenPoolUpdated(address tokenPool);

    address public tokenPool;

    /// @notice Mint the totalSupply, and transfer ownership to treasury just to have control over permit spender
    constructor(string memory name, string memory symbol, uint256 totalSupply_, address treasury)
        ERC20(name, symbol)
        ERC20Permit(name)
    {
        _mint(treasury, totalSupply_);
        _transferOwnership(treasury);
    }

    /// @dev Spender is limited to only tokenPool to prevent Signature Phishing from attackers on token holders
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        public
        virtual
        override(ERC20Permit)
    {
        if (spender != tokenPool) revert Unauthorized();
        super.permit(owner, spender, value, deadline, v, r, s);
    }

    /// @dev Set the new TokenPool address
    /// @param _tokenPool New TokenPool address
    function setTokenPool(address _tokenPool) external onlyOwner {
        tokenPool = _tokenPool;
        emit TokenPoolUpdated(_tokenPool);
    }
}
