// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./MonthlyVestingWallet.sol";


contract MetaShooterToken is ERC20, Ownable {
    using SafeMath for uint256;

    constructor() ERC20("MetaShooter", "MHUNT") {
        _mint(owner(), seedTokens);
        _mint(owner(), publicSale1Tokens);
        _mint(owner(), publicSale2Tokens);
        generateLockedTokens();
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

    address public marketingVestingWallet;
    address public teamVestingWallet;
    address public liquidityVestingWallet;

    uint64[] public marketingSchedule = [0, 1, 1, 1, 10, 0, 0, 0, 10, 0, 0, 0, 10, 0, 0, 0, 10, 0, 0, 0, 10, 0, 0, 0, 10, 0, 0, 0, 10, 0, 0, 0, 10, 0, 0, 0, 10, 0, 0, 0, 5];
    uint64[] public teamSchedule = [0, 0, 0, 0, 0, 0, 10, 0, 0, 0, 10, 0, 0, 0, 10, 0, 0, 0, 10, 0, 0, 0, 10, 0, 0, 0, 10, 0, 0, 0, 10, 0, 0, 0, 10, 0, 0, 0, 10, 0, 0, 0, 10];
    uint64[] public liquiditySchedule = [0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

    uint64 constant internal SECONDS_PER_MONTH = 2628288;
    uint64 constant internal SECONDS_PER_WEEK = SECONDS_PER_MONTH/4;

    // April 21, 2022 16:00:00
    uint256 public constant dateSaleEnd = 1650556800;

    function generateLockedTokens() internal {
        generateTeamTokens();
        generateMarketingTokens();
        generateLiquidityTokens();
    }

    function generateLiquidityTokens() internal{
        MonthlyVestingWallet lockedTokens = new MonthlyVestingWallet(owner(), uint64(dateSaleEnd), 5, liquiditySchedule, SECONDS_PER_WEEK);
        liquidityVestingWallet = address(lockedTokens);
        _mint(liquidityVestingWallet, liquidityTokens);
    }

    function generateTeamTokens() internal{
        MonthlyVestingWallet lockedTokens = new MonthlyVestingWallet(owner(), uint64(dateSaleEnd), 0, teamSchedule, SECONDS_PER_MONTH);
        teamVestingWallet = address(lockedTokens);
        _mint(teamVestingWallet, teamTokens);
    }

    function generateMarketingTokens() internal{
        MonthlyVestingWallet lockedTokens = new MonthlyVestingWallet(owner(), uint64(dateSaleEnd), 2, marketingSchedule, SECONDS_PER_MONTH);
        marketingVestingWallet = address(lockedTokens);
        _mint(marketingVestingWallet, marketingTokens);
    }
}