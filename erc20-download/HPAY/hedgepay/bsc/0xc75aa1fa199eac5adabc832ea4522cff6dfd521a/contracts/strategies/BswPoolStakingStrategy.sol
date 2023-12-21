// SPDX-License-Identifier: ISC

pragma solidity 0.8.9;

import "../../interfaces/IInvestmentStrategy.sol";
import "../../interfaces/IMasterChef.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../abstract/AbstractAssetStakingStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


contract BswPoolStakingStrategy is AssetStakingStrategy {
    using SafeERC20 for IERC20;

    constructor()
        AssetStakingStrategy(
            // Staking a1sset address -- BSW
            address(0x965F527D9159dCe6288a2219DB51fc6Eef120dD1),
            // Reward asset address -- BSW
            address(0x965F527D9159dCe6288a2219DB51fc6Eef120dD1),
            // Profit asset address -- BUSD
            address(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56)
        )
    {
        router = IUniswapV2Router02(0x3a6d8cA21D1CF76F653A67577FA0D27453350dD8);
        stakeContract = IMasterChef(0xDbc1A13490deeF9c3C12b44FE77b503c1B061739);
    }

    function pendingProfit() external view override returns (uint256) {
        uint256 currentBalance = rewardAsset.balanceOf(address(this));
        uint256 pendingBSW = currentBalance + stakeContract.pendingBSW(0, address(this));
        
        if (pendingBSW == 0) {
            return 0;
        }

        address[] memory path = new address[](3);
        path[0] = address(stakeAsset);
        path[1] = router.WETH();
        path[2] = address(profitAsset);
        uint256 profit = router.getAmountsOut(pendingBSW, path)[2];
        return profit;
    }

    function totalStaked() public override view returns(uint256 stakedAmount) {
        (stakedAmount, ) = stakeContract.userInfo(0, address(this));
        return stakedAmount;
    }

    // Return asset pool value
    function assetPoolValue() external view override returns (uint256 assetAmount, uint256 busdAmount) {
        assetAmount = totalStaked();
          if(assetAmount == 0) {
            return (0,0);
        }
        address[] memory path = new address[](3);
        path[0] = address(stakeAsset);
        path[1] = router.WETH();
        path[2] = address(profitAsset);
        busdAmount = router.getAmountsOut(assetAmount, path)[2];
    }

    function _withdrwaCapital(uint256 amount, address receiver) internal override {
        profitAsset.transfer(receiver, amount);
    }

    function _withdrawCapitalAsAssets(uint256 amount, address receiver) internal override {
        stakeAsset.transfer(receiver, amount);
    }

    function stake(uint256 _amount) internal override {
        if(_amount == 0) {
            return;
        }
        stakeAsset.safeIncreaseAllowance(address(stakeContract), _amount);
        stakeContract.enterStaking(_amount);
    }

    function unstake(uint256 _amount) internal override {
        stakeContract.leaveStaking(_amount);
    }
}
