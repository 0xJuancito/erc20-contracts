// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

contract PhemexToken is ERC20, ERC20Burnable, Ownable2Step {
    /// @notice Total number of tokens in circulation
    uint256 private _totalSupply = 1_000_000_000e18; // 1 billion PT

    constructor(address account) ERC20("Phemex Token", "PT") {
        _mint(account, _totalSupply);
    }
}
