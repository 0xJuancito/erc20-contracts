// contracts/Token.sol
// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PerpyToken is ERC20, ERC20Burnable, Ownable {
    constructor() ERC20("Perpy-Token", "PRY") {
        _mint(
            address(0xCC44a3C646ad7BD5cc5A00FD8c9B11A0bac2cC22),
            1000000000 * 10 ** decimals()
        );
    }
}
