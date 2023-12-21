// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./VestingWallet.sol";
import "./MonthlyEqualVestingWallet.sol";
import "./MonthlyEqualVestingMultiWallet.sol";
import "./MonthlyVestingWallet.sol";
import "./LGEWhitelisted.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract MetaShooterToken is Context, ERC20, Ownable, LGEWhitelisted {
    using SafeMath for uint256;

    constructor() ERC20("MetaShooter", "MHUNT") {
        _mint(owner(), seedTokens);
        _mint(owner(), publicSale1Tokens);
        _mint(owner(), publicSale2Tokens);
        _mint(owner(), marketingTokens);
        _mint(owner(), teamTokens);
        _mint(owner(), liquidityTokens);
    }

    /// Seed Sale 20.10%
    uint256 constant public seedTokens = 19095000000000000000000000; // 19 095 000 * 10**18

    /// Public Sale 1 10.00%
    uint256 constant public publicSale1Tokens = 9500000000000000000000000; // 9 500 000 * 10**18

    /// Public Sale 2 1.5%
    uint256 constant public publicSale2Tokens = 1425000000000000000000000; // 1 425 000 * 10**18

    // Marketing / Ecosystem 42.10%
    uint256 constant public marketingTokens = 39995000000000000000000000; // 19 350 000 * 10**18

    // Team / Advisers 10.50%
    uint256 constant public teamTokens = 9975000000000000000000000; // 18 060 000 * 10**18

    // Liquidity 15.80%
    uint256 constant public liquidityTokens = 15010000000000000000000000; // 24 510 000 * 10**18

    function getOwner() external view returns (address) {
        return owner();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        _applyLGEWhitelist(from, to, amount);
    }
}