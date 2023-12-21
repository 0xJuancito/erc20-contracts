// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract HAC is ERC20, Ownable {
    bool public mintingFinished = false;

    constructor() ERC20("Planet Hares - Hares Autonomous Coin", "HAC") {}

    function mint(address to) public onlyOwner {
        require(!mintingFinished);
        mintingFinished = true;

        _mint(to, 3000000000 * (10 ** decimals()));
    }
}
