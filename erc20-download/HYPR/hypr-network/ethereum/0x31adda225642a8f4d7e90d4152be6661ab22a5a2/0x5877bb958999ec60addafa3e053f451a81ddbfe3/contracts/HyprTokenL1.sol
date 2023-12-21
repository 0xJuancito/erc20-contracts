// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract OwnableGap {
    address private _owner;
    uint256[49] private __gap;
}

contract HyprTokenL1 is ERC20Upgradeable, OwnableGap {
    address public rewardsWallet;

    address public marketWallet;

    address public liquidWallet;

    uint256 public sellRewardFee;
    uint256 public sellLiquidityFee;
    uint256 public sellMarketFee;

    uint256 public buyLimit;

    mapping(address => bool) public pairs;

    mapping(address => bool) public blacklist;

    function _transfer(address from, address to, uint256 amount) internal override {
        require(amount > 0, "amount must gt 0");
        require(!blacklist[from]);

        if (pairs[from]) {
            require(amount + balanceOf(to) <= buyLimit, "over buy limit");
            super._transfer(from, to, amount);
            return;
        }

        if (pairs[to]) {
            uint256 rewardFee = (amount * sellRewardFee) / 100;
            uint256 marketFee = (amount * sellMarketFee) / 100;
            uint256 liquidFee = (amount * sellLiquidityFee) / 100;

            super._transfer(from, rewardsWallet, rewardFee);
            super._transfer(from, marketWallet, marketFee);
            super._transfer(from, liquidWallet, liquidFee);
            super._transfer(from, to, amount - rewardFee - marketFee - liquidFee);
            return;
        }
        super._transfer(from, to, amount);
    }
}
