// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FinceptorToken is ERC20 {
    constructor() ERC20("FinceptorToken", "FINC") {
        _mint(msg.sender, 100_000_000 * 10 ** decimals());
    }
}
