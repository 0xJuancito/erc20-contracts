// SPDX-License-Identifier: ISC
pragma solidity 0.8.9;

import "../../interfaces/IInvestmentStrategy.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../Fund.sol";

library FundWorkerUtils {
    event CollectError(address strategy);

    struct FundWorkerState {
        uint256 lastCollectedStrategy;
        uint8 batchSize;
    }

    function pendingCollectableProfits(FundWorkerState memory worker, Fund fund) public view returns (uint256) {
        uint256 poolSize = fund.strategyPoolSize();
        if(poolSize == 0) {
            return 0;
        }
        uint256 profit = 0;
        uint8 steps = 0;
        uint256 currentIndex = (worker.lastCollectedStrategy + 1) % poolSize;
        while (steps < worker.batchSize) {
            steps++;
            (address strategyAddress, bool exists, ) = fund.getStrategy(currentIndex);
            if(!exists) {
                if(currentIndex == worker.lastCollectedStrategy) {
                    break;
                }

                currentIndex = (currentIndex + 1) %  poolSize;
               
                continue;
            }
         
            IInvestmentStrategy strategy = IInvestmentStrategy(strategyAddress);

            try strategy.pendingProfit() returns (uint256 pendingProfit) {
                profit += pendingProfit;
            } catch {
                // do nothing
            }
            
            if(currentIndex == worker.lastCollectedStrategy) {
                break;
            }
            
            currentIndex = (currentIndex + 1) % poolSize;
        }
        return profit;
    }

    function collectProfitBatch(FundWorkerState storage worker, Fund fund) public returns (uint256) {
        uint256 poolSize = fund.strategyPoolSize();
        if(poolSize == 0) {
            return 0;
        }
        uint8 steps = 0;
        uint256 currentIndex = (worker.lastCollectedStrategy + 1) % poolSize;
        uint256 totalReward = 0;
        while (steps < worker.batchSize) {
            steps++;
            (address strategyAddress, bool exists, ) = fund.getStrategy(currentIndex);
            
            if(!exists) {
                if(currentIndex == worker.lastCollectedStrategy) {
                    break;
                }
                currentIndex = (currentIndex + 1) % poolSize;
                continue;
            }
         
            IInvestmentStrategy strategy = IInvestmentStrategy(strategyAddress);
            (, uint256 amount) = fund.collectProfit(strategy); 
            totalReward += amount;
               
            if(currentIndex == worker.lastCollectedStrategy) {
                break;
            }

            currentIndex = (currentIndex + 1) % poolSize;
        }
        fund.stashProfitPool();
        worker.lastCollectedStrategy = currentIndex;
        return totalReward;
    }
}
