// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract SonorusToken is ERC20 {
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10 ** 18;
    constructor(address initialOwner) ERC20("SonorusToken", "SNS") {
        _mint(initialOwner, MAX_SUPPLY);
    }
}
