// SPDX-License-Identifier: ISC
pragma solidity 0.8.9;

import "../../interfaces/IInvestmentStrategy.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

library FundUtils {

    event CollectError(address strategyId, bytes msg);
    event WithdrawError(address strategyId, bytes msg);

    struct StrategyConfiguration {
        bool exists;
        uint8 capitalAllocation;
        uint256 key;
    }

    struct FundClient {
        bool exists;
        uint8 profitAllocation;
        uint256 pendingProfit;
        uint256 key;
    }

    struct RewardSnapshot {
        uint256 time0;
        uint256 total0;
        uint256 time1;
        uint256 total1;
    }

    struct InvestmentLog {
        uint256 lastInvestmentIndex;
        uint256 busdCapitalPool;
        uint256 profitPool;
    }

    function collectProfit(IInvestmentStrategy strategy) internal returns (bool, uint256) {
        // Collect BUSD profits each strategy
        try strategy.collectProfit(address(this)) returns (uint256 profit) {
            return (true, profit);
        } catch (bytes memory _err) {
            emit CollectError(address(strategy), _err);
            return (false, 0);
        }
    }

    function withdrawCapital(IInvestmentStrategy strategy, address vaultAddress, bool keepCapitalAsAssets) internal returns (bool) {
        bool success = true; 
        if (!keepCapitalAsAssets) {
            try strategy.withdrawCapital(0, vaultAddress) {
            } catch (bytes memory _err) {
                emit WithdrawError(address(strategy), _err);
                success = false;
            }
        } else {
            try strategy.withdrawCapitalAsAssets(0, vaultAddress) {  
            } catch (bytes memory _err) {
                emit WithdrawError(address(strategy), _err);
                success = false;
            }
        }
        return success;
    }
}
