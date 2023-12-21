// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import {StakingControllerLib} from "./StakingControllerLib.sol";
import {
    SafeMathUpgradeable
} from "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ViewExecutor} from "../util/ViewExecutor.sol";

contract StakingControllerTemplate is OwnableUpgradeable {
    using SafeMathUpgradeable for *;
    StakingControllerLib.Isolate isolate;

    function currentCycle() public view returns (uint256 cycle) {
        cycle = isolate.currentCycle;
    }

    function commitmentViolationPenalty()
        public
        view
        returns (uint256 penalty)
    {
        penalty = isolate.commitmentViolationPenalty;
    }

    function dailyBonusesAccrued(address user)
        public
        view
        returns (uint256 amount)
    {
        amount = isolate.dailyBonusesAccrued[user];
    }
}
