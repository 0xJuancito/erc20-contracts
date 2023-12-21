// SPDX-License-Identifier: ISC

pragma solidity 0.8.9;

import "../../interfaces/IInvestmentStrategy.sol";
import "../../interfaces/IMasterChef.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../abstract/AbstractAssetStakingStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


contract CakePoolStakingStrategy is AssetStakingStrategy {
    using SafeERC20 for IERC20;

    constructor() AssetStakingStrategy(
            // Staking asset address -- Cake
            address(0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82),
            // Reward asset address -- Cake
            address(0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82),
            // Profit asset address -- BUSD
            address(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56)
        )
    {
        router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        stakeContract = IMasterChef(0x73feaa1eE314F8c655E354234017bE2193C9E24E);
    }

    function pendingProfit() external view override returns (uint256) {
        uint256 currentBalance = rewardAsset.balanceOf(address(this));
        uint256 pendingCake = currentBalance + stakeContract.pendingCake(0, address(this));

        if (pendingCake == 0) {
            return 0;
        }

        address[] memory path = new address[](3);
        path[0] = address(stakeAsset);
        path[1] = router.WETH();
        path[2] = address(profitAsset);
        uint256 profit = router.getAmountsOut(pendingCake, path)[2];
        return profit;
    }

    function _withdrwaCapital(uint256 amount, address receiver) internal override {
        profitAsset.transfer(receiver, amount);
    }

    function _withdrawCapitalAsAssets(uint256 amount, address receiver) internal override {
        stakeAsset.transfer(receiver, amount);
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
