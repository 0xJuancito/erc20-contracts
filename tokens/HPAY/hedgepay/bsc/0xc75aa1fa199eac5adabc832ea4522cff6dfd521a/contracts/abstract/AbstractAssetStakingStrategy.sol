// SPDX-License-Identifier: ISC

pragma solidity 0.8.9;

import "../../interfaces/IInvestmentStrategy.sol";
import "../../interfaces/IMasterChef.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../lib/SwapUtils.sol";
import "./AbstractLock.sol";

abstract contract AssetStakingStrategy is IInvestmentStrategy, AccessControl, Lock {
    using SafeERC20 for IERC20;
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    
    // Use this max investment to avoid slippage loss
    uint256 public maxEthSwap = type(uint256).max;
    uint256 public maxBusdSwap = type(uint256).max;  
    uint256 public swapSlippage = 150; // 1.5% slippage
    uint256 public busdCapitalPool;

    IMasterChef public stakeContract;
    IERC20 public stakeAsset;
    IERC20 public rewardAsset;
    IERC20 public profitAsset;
    IERC20 public busd;

    // The router used to swap the fee into BNB or stable coin
    IUniswapV2Router02 public router;

    event SwapFailed(address from, address to, uint256 amount, uint256 slippage);
    constructor(
        address stakeAssetAddress,
        address rewardAssetAddress,
        address profitAssetAddress
    ) {
        stakeAsset =  IERC20(stakeAssetAddress);
        rewardAsset = IERC20(rewardAssetAddress);
        profitAsset = IERC20(profitAssetAddress);

        busd = ERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(OWNER_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, msg.sender);
    }

    function addBusdCapital(uint256 amount) override external {
        require(
            amount > 0,
            "ASSET POOL STRATEGY: Capital amount must be grater than 0"
        );

        busd.safeTransferFrom(msg.sender, address(this), amount);
        busdCapitalPool += amount;

        handleBusdInvestment();
    }

    // Add capital to the investment strategy
    function addAssetCapital(uint256 amount) override external  {
        require(
            amount > 0,
            "ASSET POOL STRATEGY: Capital amount must be grater than 0"
        );

        stakeAsset.safeTransferFrom(msg.sender, address(this), amount);
        stake(amount);
    }

    // Add capital to the investment strategy
    function addCapital() external payable override {
        require(
            msg.value > 0,
            "ASSET POOL STRATEGY: Capital amount must be grater than 0"
        );
    
        handleBnbInvestment();
    }
    
    function handleBusdInvestment() internal { 
        if(busdCapitalPool == 0) {
            return;
        }

        uint256 swapAmount = busdCapitalPool;
        
        if(swapAmount > maxBusdSwap) {
            swapAmount = maxBusdSwap;   
        } 

        uint256 balance = stakeAsset.balanceOf(address(this));
        try SwapUtils.swapTokensForTokens(router, busd, stakeAsset, swapAmount, swapSlippage) {
            busdCapitalPool -= swapAmount;
            uint256 stakeBalance = stakeAsset.balanceOf(address(this)) - balance;
            stake(stakeBalance);
        } catch {
            emit SwapFailed(address(busd), address(stakeAsset), swapAmount, swapSlippage);
        }
    }

    function drainCapitalPool(address receiver) public onlyRole(OWNER_ROLE) lock {
        busd.transfer(receiver, busd.balanceOf(address(this)));
        busdCapitalPool = 0;
    }

    function handleBnbInvestment() internal { 
        // Swap the new capital to the assets
        uint256 ethAmount = address(this).balance;
        
        if(ethAmount == 0) {
            return;
        }

        if(ethAmount > maxEthSwap) {
            ethAmount = maxEthSwap;
        }

        uint256 balance = stakeAsset.balanceOf(address(this));
        try SwapUtils.swapETHForTokens(router, stakeAsset, ethAmount, swapSlippage) {
            uint256 stakeBalance = stakeAsset.balanceOf(address(this)) - balance;
            stake(stakeBalance);
        } catch {
            emit SwapFailed(address(busd), address(stakeAsset), ethAmount, swapSlippage);
        }
    }
    
    // Remove capital from the strategy
    function withdrawCapital(uint256 amount, address receiver) public override onlyRole(MANAGER_ROLE) lock {
        // Unstake tokens before removing capital
        uint256 assetAmount = totalStaked();

        if(assetAmount == 0) {
            return; 
        } 

        if(assetAmount < amount || amount == 0) { 
            amount = assetAmount; 
        }

        unstake(amount);
       
        // Swap the new capital to the assets
        uint256 tokenAmount = stakeAsset.balanceOf(address(this));
        require(tokenAmount > 0, "Insuficient balance");
        SwapUtils.swapTokensForTokens(router, stakeAsset, profitAsset, tokenAmount, swapSlippage);

        uint256 balance = profitAsset.balanceOf(address(this));
        _withdrwaCapital(balance, receiver);

        // Remove any busd remains
        busd.transfer(receiver, busd.balanceOf(address(this)));
        busdCapitalPool = 0;
    }

    function withdrawCapitalAsAssets(uint256 amount, address receiver) override external onlyRole(MANAGER_ROLE) {
        // Unstake tokens before removing capital
        uint256 assetAmount = totalStaked();
        unstake(assetAmount);

        if(assetAmount == 0) {  
            return; 
        } 

        if(assetAmount < amount || amount == 0) {
            amount = assetAmount;
        }

        uint256 balance = stakeAsset.balanceOf(address(this));
        _withdrawCapitalAsAssets(balance, receiver);
        // Remove any busd remains
        busd.transfer(receiver, busd.balanceOf(address(this)));
        busdCapitalPool = 0;
    }

    function totalStaked() public view virtual returns(uint256 stakedAmount) ;

    function destroy(address receiver) external onlyRole(OWNER_ROLE) {
        // Distribute any remaning tokens
        _collectProfit(receiver);
        withdrawCapital(0, receiver);

        require(
            stakeAsset.balanceOf(address(this)) == 0,
            "StakeAsset balance != 0 cannot destroy"
        );

        require(
            rewardAsset.balanceOf(address(this)) == 0,
            "Reward asset balance != 0 cannot destory"
        );

        require(
            busd.balanceOf(address(this)) == 0,
            "Busd asset balance != 0 cannot destory"
        );

        uint256 assetAmount = totalStaked();

        require(assetAmount == 0, "Balance != 0 cannot destroy");

        // Call self destruct and send remaing ETH to owner
        selfdestruct(payable(msg.sender));
    }

    // Collect the profits
    function collectProfit(address _receiver) external override onlyRole(MANAGER_ROLE) returns(uint256) {
       return _collectProfit(_receiver);
    }

    function _collectProfit(address _receiver) private returns(uint256) {
        uint256 pendingProfits = this.pendingProfit();
        if (pendingProfits == 0) {
            return 0;
        }

        unstake(0);
        uint256 tokenAmount = rewardAsset.balanceOf(address(this));
        require(tokenAmount > 0, "Insuficient balance");
        try SwapUtils.swapTokensForTokens(router, rewardAsset, profitAsset, tokenAmount, swapSlippage) {
            pendingProfits = profitAsset.balanceOf(address(this));
            profitAsset.transfer(_receiver, pendingProfits);
            return pendingProfits;
        } catch {
            emit SwapFailed(address(busd), address(stakeAsset), tokenAmount, swapSlippage);
            return 0;
        }
    }

    function rollProfit() override external onlyRole(MANAGER_ROLE) {
        unstake(0);
        stake(stakeAsset.balanceOf(address(this)));
    }

    function rollCapitalPools() external {
        handleBusdInvestment();
        handleBnbInvestment();
    }

    function setSwapSlippage(uint256 slipapge) external onlyRole(MANAGER_ROLE) {
        require(slipapge <= 10_000, "Slippage cannot be > 100%");
        swapSlippage = slipapge;
    }

    function setBusdSwapCap(uint256 maxAmount) external onlyRole(MANAGER_ROLE) {
        maxBusdSwap = maxAmount;
    }

    function setEthSwapCap(uint256 maxAmount) external onlyRole(MANAGER_ROLE) {
        maxEthSwap = maxAmount;
    }

    function setRouter(address routerAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        router = IUniswapV2Router02(routerAddress);
    }

    function _withdrwaCapital(uint256 amount, address receiver) internal virtual;
    function _withdrawCapitalAsAssets(uint256 amount, address receiver) internal virtual;

    function stake(uint256 _amount) internal virtual;
    function unstake(uint256 _amount) internal virtual;

    receive() external payable {}
}
