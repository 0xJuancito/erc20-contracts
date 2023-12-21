// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IMintedToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MINTED Token
 */
contract MintedToken is ERC20, Ownable, IMintedToken {
    uint256 public immutable _SUPPLY_CAP; //1000000000000000000000000000  1 billion

    /**
     * @notice Constructor
     * @param addresses addresses to receive premint tokens
     * @param amounts tokens quantity to distribute to addresses
     */
    constructor(
        address[] memory addresses,
        uint256[] memory amounts,
        uint256 _preMintAmount,
        uint256 _supply_cap
    ) ERC20("Minted Token", "MTD") {
        require(_preMintAmount <= _supply_cap, "Minted: premint amount exceeds supply cap");
        require(addresses.length == amounts.length, "Minted: length mismatch");
        _SUPPLY_CAP = _supply_cap;
        for (uint256 i = 0; i < amounts.length; i++) {
            require(addresses[i] != address(0), "Invalid address");
            _mint(addresses[i], amounts[i]);
        }
        require(totalSupply() == _preMintAmount, "Minted: pre-mint amount mismatch with amounts");
    }

    /**
     * @notice Mint MINTED tokens
     * @param account address to receive tokens
     * @param amount amount to mint
     * @return status true if mint is successful, false if not
     */
    function mint(address account, uint256 amount) external override onlyOwner returns (bool status) {
        if (totalSupply() + amount <= _SUPPLY_CAP) {
            _mint(account, amount);
            return true;
        }
        return false;
    }

    /**
     * @notice View supply cap
     */
    function SUPPLY_CAP() external view override returns (uint256) {
        return _SUPPLY_CAP;
    }
}
