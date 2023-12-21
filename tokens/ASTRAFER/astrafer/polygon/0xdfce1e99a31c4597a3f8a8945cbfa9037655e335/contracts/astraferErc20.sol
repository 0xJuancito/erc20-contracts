// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Astrafer is ERC20 {
    uint256 public constant INITIAL_SUPPLY = 888077888 * (10**uint256(18));

    constructor() ERC20("Astrafer", "ASTRAFER") {
        _mint(0x388a18601d8f34b4A912a29A4429FAfeE70F9ED4, INITIAL_SUPPLY);
    }
}