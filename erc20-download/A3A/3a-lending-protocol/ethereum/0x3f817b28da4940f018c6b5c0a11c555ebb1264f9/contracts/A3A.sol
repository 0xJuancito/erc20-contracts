pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract A3A is ERC20 {

    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 ether;

    constructor() ERC20("3A Utility Token", "A3A") {
        _mint(msg.sender, TOTAL_SUPPLY);
    }

}
