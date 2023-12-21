// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

import "../token/oft/v2/OFTV2.sol";

/// @title A LayerZero OmnichainFungibleToken
/// @notice Use this contract only on the BASE CHAIN. It locks tokens on source, on outgoing send(), and unlocks tokens when receiving from other chains.
contract WeFi is OFTV2, ERC20Permit, ERC20Votes {
    constructor(address _layerZeroEndpoint, uint _initialSupply, address receiver, uint8 _sharedDecimals) OFTV2("WeFi", "WEFI", _sharedDecimals, _layerZeroEndpoint) ERC20Permit("WeFi") {
        _mint(receiver, _initialSupply);
    }

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }
}
