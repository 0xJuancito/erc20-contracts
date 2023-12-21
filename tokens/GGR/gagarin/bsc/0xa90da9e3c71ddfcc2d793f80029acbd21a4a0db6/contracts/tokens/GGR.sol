pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract GGR is ERC20, ERC20Burnable {
    constructor(address recipient) ERC20("Gagarin", "GGR") {
        _mint(recipient, 100e6 * 10**18);
    }
}
