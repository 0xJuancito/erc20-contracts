// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Token is ERC20, Ownable {

    mapping(string => bool) public txData;

    constructor() public ERC20("BUY Token", "BUY") {
    }

    function mint(address to, uint256 amount, string memory txhash) external onlyOwner {
        require(txData[txhash] == false, "tx already mined");
        txData[txhash] = true;
        _mint(to, amount);
    }

    function burn(address to, uint256 amount, string memory txhash) external onlyOwner {
        require(txData[txhash] == false, "tx already burned");
        txData[txhash] = true;
        _burn(to, amount);
    }
}