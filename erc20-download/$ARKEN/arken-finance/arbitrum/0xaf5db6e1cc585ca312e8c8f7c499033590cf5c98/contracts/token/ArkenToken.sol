// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.16;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract ArkenToken is ERC20 {
    constructor(
        address _to,
        uint256 _totalSupply
    ) ERC20('Arken Token', 'ARKEN') {
        _mint(_to, _totalSupply);
    }
}
