// SPDX-License-Identifier: ISC

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../RewardManager.sol";
import "../abstract/AbstractYielder.sol";

contract HedgeDeposit is AbstractYielder {
  
    RewardManager public rewardManager;
    // Claim fee %
    uint8 public claimFee = 5;  
    address public feeAddress;

    ERC20 public asset;

    constructor(
        address _rewardManagerAddress,
        address _hedgeCoinAddress,
        address _feeAddress
    ) {
        rewardManager = RewardManager(payable(_rewardManagerAddress));
        feeAddress = _feeAddress;
        asset =  ERC20(_hedgeCoinAddress);
    }
    
    function setFeeAddress(address _feeAddress) public onlyOwner {
        require(_feeAddress != address(0), "Address cannot be 0");
        feeAddress = _feeAddress;
    }

    function _totalReward() override internal view returns (uint256) {
        return rewardManager.unclaimedRewardValue(address(this));
    }

    function _sweepOutstandingReward(uint256 reward) internal override {
        if(reward > 0) {
            rewardManager.claimRewardTo(reward, feeAddress);
        }
    }

    function _claimReward(uint256 reward, address receiver) override internal {
        uint256 fee = (reward * claimFee) / 100;
        rewardManager.claimRewardTo(reward - fee, receiver);
        rewardManager.claimRewardTo(fee, feeAddress);
    }

    function _deposit(uint256 amount, address sender) override internal {
        asset.transferFrom(sender, address(this), amount);
    }

    function _withdraw(uint256 amount, address receiver) override internal {
        asset.transfer(receiver, amount);
    }
}
