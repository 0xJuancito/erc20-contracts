// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract UN is ERC20, ERC20Burnable {
    constructor(address holder) ERC20("Unbound", "UN") {
        _mint(holder, 1000000000 * 10 ** 18);
    }
}
