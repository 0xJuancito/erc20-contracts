// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {FloorToken, ILBFactory} from "./FloorToken.sol";
import {TransferTripleTaxToken} from "./TransferTripleTaxToken.sol";
import {ERC20, IERC20} from "./TransferTaxToken.sol";

contract PK is FloorToken, TransferTripleTaxToken {
    constructor(
        string memory name,
        string memory symbol,
        address owner,
        IERC20 tokenY,
        ILBFactory lbFactory,
        uint24 activeId,
        uint16 binStep,
        uint256 tokenPerBin
    )
        FloorToken(tokenY, lbFactory, activeId, binStep, tokenPerBin)
        TransferTripleTaxToken(name, symbol, owner)
    {}

    function totalSupply()
        public
        view
        override(ERC20, FloorToken)
        returns (uint256)
    {
        return ERC20.totalSupply();
    }

    function balanceOf(
        address account
    ) public view override(FloorToken, ERC20) returns (uint256) {
        return ERC20.balanceOf(account);
    }

    function _mint(
        address account,
        uint256 amount
    ) internal override(FloorToken, ERC20) {
        ERC20._mint(account, amount);
    }

    function _burn(
        address account,
        uint256 amount
    ) internal override(FloorToken, ERC20) {
        ERC20._burn(account, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(FloorToken, ERC20) {
        FloorToken._beforeTokenTransfer(from, to, amount);
    }
}
