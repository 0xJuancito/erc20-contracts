// SPDX-License-Identifier: ISC

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./AbstractLock.sol";
import "../lib/FundUtils.sol";
import "../../interfaces/IFundManager.sol";
import "../../interfaces/IInvestmentStrategy.sol";
import "../../interfaces/IStash.sol";

abstract contract AbstractFund is AccessControl, IFund, Lock {
    using EnumerableMap for EnumerableMap.UintToAddressMap;
    event CollectError(address strategy);
    event WithdrawError(address strategy);
    uint256 lastKey = 1;
    
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant WORKER_ROLE = keccak256("WORKER_ROLE");

    uint8 public unallocatedCapital = 100;
    uint8 public unallocatedProfit = 100;
    // Collect profits reward percent 100 = 1%
    uint16 public collectProfitReward = 50;
    uint256 public totalRewardsClaimed;

    // The reward asset, BUSD for now
    ERC20 public rewardAsset;
    ERC20 public usd;
    FundUtils.InvestmentLog public invstementLog;
    FundUtils.RewardSnapshot public rewardSnapShot;

    EnumerableMap.UintToAddressMap private strategyIndex;
    mapping(address => FundUtils.StrategyConfiguration) strategies;

    constructor(address _rewardAsset, address usdAddress) {
        rewardAsset = ERC20(_rewardAsset);
        usd = ERC20(usdAddress);

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MANAGER_ROLE, msg.sender);
        _setupRole(WORKER_ROLE, msg.sender);
    }

    function strategyPoolSize() external view returns (uint256) {
        return strategyIndex.length();
    }

    function stashProfitPool() external {
        require(
            hasRole(WORKER_ROLE, msg.sender) ||
            hasRole(MANAGER_ROLE, msg.sender) ||
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Permission denied"
        );

        stashProfit();
    }

    // Stash profits
    function stashProfit() internal {
        if (invstementLog.profitPool > 0) {
            _stashProfit(invstementLog.profitPool);
            invstementLog.profitPool = 0;
        }
    }

    function stashCapitalPool() external onlyRole(MANAGER_ROLE) {
        _stashBUSDCapital();
    }

    function _stashBUSDCapital() internal {
        if (invstementLog.busdCapitalPool > 0) {
            _stashCapitalPool(invstementLog.busdCapitalPool);
            invstementLog.busdCapitalPool = 0;
        }
    }

    function stashETHCapitalPool() external onlyRole(MANAGER_ROLE) {
        _stashETHCapital();
    }

    function _stashETHCapital() internal {
        if (address(this).balance > 0) {
            _stashETHCapitalPool(address(this).balance);
        }
    }

    function invest() external payable override lock {
        handleInvestment();
    }

    function investBUSD(uint256 amount) external override lock {
        addFundsToCapitalPool(amount);
        handleInvestment();
    }

    function addFundsToCapitalPool(uint256 amount) public {
        invstementLog.busdCapitalPool += amount;
        usd.transferFrom(msg.sender, address(this), amount);
    }

    // Update the reward snapshot
    function updateRewardSnap() external {
        _updateRewardSnap();
    }

    // Claim rewards
    function claim(uint256 amount) external override lock {
        _claim(amount, msg.sender);
        totalRewardsClaimed += amount;
    }

    // Claim  rewards into  address
    function claimTo(uint256 amount, address _destination) external override lock {
        _claim(amount, _destination);
        totalRewardsClaimed += amount;
    }

    // Handle Profit Claims
    function _claim(uint256 amount, address _destination) internal virtual;

    // Handle Stashing
    function _stashProfit(uint256 availableProfit) internal virtual;
    function _stashCapitalPool(uint256 availableCapital) internal virtual;
    function _stashETHCapitalPool(uint256 availableCapital) internal virtual;

    // Get total pending rewards value of an address
    function _pendingRewards() internal view virtual returns (uint256);

    //Should return the vault Address
    function _vaultAddress() internal view virtual returns (address);

    function totalGenerateRewards() public view virtual returns (uint256);

    function vaultAddress() external view returns (address) {
        return _vaultAddress();
    }

    // Get total pending rewards value of an address
    function pendingRewards() external view override returns (uint256) {
        return _pendingRewards();
    }

    function handleInvestment() internal {
        uint256 length = strategyIndex.length();

        if (length == 0) {
            return;
        }

        invstementLog.lastInvestmentIndex = (invstementLog.lastInvestmentIndex + 1) % length;
        (, address strategyAddress) = strategyIndex.at(invstementLog.lastInvestmentIndex);

        FundUtils.StrategyConfiguration memory strategyConfig = strategies[strategyAddress];

        if (strategyConfig.capitalAllocation == 0 ) {
            return;
        }

        IInvestmentStrategy strategy = IInvestmentStrategy(strategyAddress);

        if (invstementLog.busdCapitalPool > 0) {
            uint256 busdCapitalAllocation = (invstementLog.busdCapitalPool * strategyConfig.capitalAllocation) / 100;
            usd.increaseAllowance(strategyAddress, busdCapitalAllocation);
            strategy.addBusdCapital(busdCapitalAllocation);
            invstementLog.busdCapitalPool -= busdCapitalAllocation; 
        }

        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            uint256 ethCapitalAllocation = (ethBalance * strategyConfig.capitalAllocation) / 100;
            strategy.addCapital{value: ethCapitalAllocation}();
        }
    }

    function getNewKey() internal returns (uint256) {
        return lastKey++;
    }

    function pendingProfits() public view returns (uint256) {
        uint256 profit = 0; 
        for (uint256 index = 0; index < strategyIndex.length(); index++) {
            (, address strategyAddress) = strategyIndex.at(index); 

            IInvestmentStrategy strategy = IInvestmentStrategy(strategyAddress);
            profit += strategy.pendingProfit();
        } 
        return profit;
    }

    // Add a new strategy
    function addStrategy(address _strategyAddress) external override onlyRole(MANAGER_ROLE) {
        if (strategies[_strategyAddress].exists) {
            return;
        }
        strategies[_strategyAddress] = FundUtils.StrategyConfiguration({
            capitalAllocation: 0,
            exists: true,
            key: getNewKey()
        });

        strategyIndex.set(strategies[_strategyAddress].key, _strategyAddress);
    }

    // Remove a strategy 
    function removeStrategy(address _strategyId, bool keepCapitalAsAssets, bool force) external override onlyRole(MANAGER_ROLE) {
        if (!strategies[_strategyId].exists) {
            return;
        }
        uint256 key = strategies[_strategyId].key;
        if (!force) {
            IInvestmentStrategy strategy = IInvestmentStrategy(_strategyId);
            (bool success,uint256 pendingProfit) = FundUtils.collectProfit(strategy);
            require(success, "Could not collect profit");

            invstementLog.profitPool += pendingProfit;
        
            stashProfit();

            bool result = withdrawCapital(strategy, keepCapitalAsAssets);
            require(result, "Could not withdraw capital");
        }

        strategyIndex.remove(key);
        unallocatedCapital += strategies[_strategyId].capitalAllocation;
        delete strategies[_strategyId]; 
    }

    function updateAllocation(address _strategyId, uint8 allocation) external override onlyRole(MANAGER_ROLE) {
        require(allocation <= 100, "Allocation overflow");
        FundUtils.StrategyConfiguration storage strategyConfig = strategies[_strategyId];

        if (strategyConfig.capitalAllocation >= allocation) {
            unallocatedCapital += strategyConfig.capitalAllocation - allocation;
        } else {
            require(strategyConfig.capitalAllocation + unallocatedCapital >= allocation, "Insuficient reserve");
            unallocatedCapital -= allocation - strategyConfig.capitalAllocation;
        }
        strategyConfig.capitalAllocation = allocation;
    }

    function totalCapitalValue() external view returns (uint256) {
        uint256 result = 0;
        for (uint256 index = 0; index < strategyIndex.length(); index++) {
            (, address strategyAddress) = strategyIndex.at(index);

            IInvestmentStrategy strategy = IInvestmentStrategy(strategyAddress);
            (, uint256 busdAmount) = strategy.assetPoolValue();
            result += busdAmount;
        }
        return result;
    }

    function collectProfit(IInvestmentStrategy strategy) external onlyRole(WORKER_ROLE) returns(bool, uint256) {
        (bool success, uint256 pendingProfit) = FundUtils.collectProfit(strategy);
        if(success && pendingProfit > 0) {
            uint256 reward = (pendingProfit * collectProfitReward) / 10_000;
            invstementLog.profitPool += pendingProfit - reward;
            usd.transfer(address(msg.sender), reward);
            return (success, reward);
        }

        return (success, 0);
    }

    function withdrawCapital(IInvestmentStrategy strategy, bool keepCapitalAsAssets) internal returns (bool) {
        return FundUtils.withdrawCapital(strategy, _vaultAddress(), keepCapitalAsAssets);
    }

    function _updateRewardSnap() internal {
        if (block.timestamp - rewardSnapShot.time0 > 5 minutes) { 
            rewardSnapShot.time1 = rewardSnapShot.time0;
            rewardSnapShot.total1 = rewardSnapShot.total0;
        }
        rewardSnapShot.time0 = block.timestamp;
        rewardSnapShot.total0 = totalGenerateRewardsWithProfits();
    }

    function totalGenerateRewardsWithProfits() public view returns(uint256) {
        uint256 currentPendingProfits = pendingProfits();
        return totalGenerateRewards() + currentPendingProfits;
    }

    function getStrategy(uint256 index) external view override returns (address id, bool exists, uint8 allocation) {
        (, address strategyAddress) = strategyIndex.at(index);
        FundUtils.StrategyConfiguration memory strategyConfig = strategies[strategyAddress];

        return (
            strategyAddress,
            strategyConfig.exists,
            strategyConfig.capitalAllocation
        );
    }

    function getStrategyByAddress(address _address) external view override returns (uint256 key, bool exists, uint8 allocation) {
        FundUtils.StrategyConfiguration memory strategyConfig = strategies[_address];
        return (
            strategyConfig.key,
            strategyConfig.exists,
            strategyConfig.capitalAllocation
        );
    }

    /** Use this to free any locked capital */
    function directBusdToStrategy(address strategyAddress, uint256 amount, bool force) external onlyRole(MANAGER_ROLE) {
        require(usd.balanceOf(address(this)) > 0, "Insuficient funds");
        require(force || invstementLog.busdCapitalPool >= amount, "Insuficient investment funds"); 
        require(strategies[strategyAddress].exists, "Strategy does not exist");
        usd.increaseAllowance(strategyAddress, amount);
        IInvestmentStrategy(strategyAddress).addBusdCapital(amount);
        if(invstementLog.busdCapitalPool >= amount) {
            invstementLog.busdCapitalPool -= amount;
        } 
    }

    /** Use this to free any locked capital */
    function directETHToStrategy(address strategyAddress, uint256 amount) external onlyRole(MANAGER_ROLE) {
        require(address(this).balance >= amount, "Insuficient funds");
        require(strategies[strategyAddress].exists, "Strategy does not exist");
        IInvestmentStrategy(strategyAddress).addCapital{value: amount}();
    }

    function profitPool() external view returns(uint256) {
        return invstementLog.profitPool;
    }   

    function destroy() external onlyRole(DEFAULT_ADMIN_ROLE)  {
        _stashBUSDCapital();
        _stashETHCapital();
        stashProfit();

        if(usd.balanceOf(address(this)) > 0) {
            usd.transfer(_vaultAddress(), usd.balanceOf(address(this)));
        }

        selfdestruct(payable(_vaultAddress()));
    }

    function setCollectProfitReward(uint16 newReward) external onlyRole(MANAGER_ROLE) {
        require(newReward > 0 && newReward < 10_000, "Reward must be between 0 and 100%");
        collectProfitReward = newReward;
    } 

    receive() external payable {

    }
}
