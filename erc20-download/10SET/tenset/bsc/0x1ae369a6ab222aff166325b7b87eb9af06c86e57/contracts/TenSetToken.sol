// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import { ERC20AnySwap } from "./ERC20AnySwap.sol";

contract TenSetToken is ERC20AnySwap {
    constructor(address _owner, uint256 totalSupply) ERC20AnySwap(_owner) {
        _setOwner(_owner);
        _mint(_owner, totalSupply);
    }
}
