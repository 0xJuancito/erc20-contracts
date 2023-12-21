// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.1;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";

contract DastraERC20 is ERC2771Context, ERC20Capped, Ownable {
    uint8 private _decimals;

    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint8 decimals_,
        uint256 _cap,
        address trustedForwarder,
        address owner
    ) ERC2771Context(trustedForwarder) ERC20Capped(_cap) ERC20(name, symbol) {
        _mint(owner, initialSupply);
        _decimals = decimals_;
        _transferOwnership(owner);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function _msgSender() internal view virtual override(Context, ERC2771Context) returns (address sender) {
        return ERC2771Context._msgSender();
    }

    function _msgData() internal view virtual override(Context, ERC2771Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }
}
