// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MT1 is ERC20, Ownable {

    constructor() ERC20("1move", "1MT") {}    //BUSD
    address public mainAddr;

    function setMainAddr(address _mainAddr) external onlyOwner {
        mainAddr = _mainAddr;
    }

    function mint(uint256 amount) external {
        require(msg.sender == mainAddr, "Address is not the main address");
        _mint(mainAddr, amount);
    }

}