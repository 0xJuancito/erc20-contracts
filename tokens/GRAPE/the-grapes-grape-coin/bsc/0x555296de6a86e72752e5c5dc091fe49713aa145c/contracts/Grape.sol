// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract Grape is ERC20 {
    constructor(address preMintWallet_) ERC20('Grape coin', 'GRAPE') {
        _mint(preMintWallet_, 2_000_000_000 * 10 ** decimals());
    }
}
