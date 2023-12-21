// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import '@openzeppelin/contracts/utils/math/SafeMath.sol';

contract Rabbit is ERC20, ERC20Burnable, Ownable {
    using SafeMath for uint256;
    uint256 public MAX_SUPPLY = 136000000 * 10 ** decimals(); // 136,000,000

    constructor() ERC20("Rabbit", "RAB") {
        _mint(msg.sender, 100000000 * 10 ** decimals()); // 100,000,000
    }

    function mint(address to, uint256 amount) public onlyOwner {
        require(totalSupply().add(amount) <= MAX_SUPPLY, "RAB::max total supply");
        _mint(to, amount);
    }
}