// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CoinbetToken is ERC20Burnable, Ownable {
    uint256 private constant SUPPLY = 100_000_000 * 10**18;

    constructor() ERC20("Coinbet Finance", "CFI") {
        _mint(msg.sender, SUPPLY);
    }

    function mint(address to, uint256 amount) public virtual onlyOwner {
        _mint(to, amount);
    }
}
