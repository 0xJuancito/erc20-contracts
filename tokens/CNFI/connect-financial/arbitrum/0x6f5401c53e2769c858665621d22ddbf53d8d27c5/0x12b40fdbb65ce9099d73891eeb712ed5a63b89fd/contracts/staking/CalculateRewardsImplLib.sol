// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import {StakingControllerLib} from "./StakingControllerLib.sol";
import {
    SafeMathUpgradeable
} from "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import {
    MathUpgradeable as Math
} from "@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";
import {UpdateRedeemableImplLib} from "./UpdateRedeemableImplLib.sol";

library CalculateRewardsImplLib {
    using SafeMathUpgradeable for *;
    struct CalculateRewardsLocals {
        uint256 weight;
        uint256 totalWeight;
        uint256 daysToRedeem;
        uint256 amountRedeemed;
    }

    function _calculateRewards(
        StakingControllerLib.Isolate storage isolate,
        address _user,
        uint256 amt,
        bool isView
    ) internal returns (uint256 amountToRedeem, uint256 bonuses) {
        StakingControllerLib.DailyUser storage user = isolate.dailyUsers[_user];
        (amountToRedeem, bonuses) = _computeRewards(isolate, _user);

        require(
            isView || amountToRedeem >= amt,
            "cannot redeem more than whats available"
        );
        uint256 _redeemable = user.redeemable;
        if (amt == 0) amt = _redeemable;
        user.redeemable = _redeemable.sub(amt);
        return (amt, bonuses);
    }

    function _computeRewards(
        StakingControllerLib.Isolate storage isolate,
        address _user
    ) internal view returns (uint256 amountToRedeem, uint256 bonuses) {
        amountToRedeem = isolate.dailyUsers[_user].redeemable;
        bonuses = isolate.dailyBonusesAccrued[_user];
    }
}
