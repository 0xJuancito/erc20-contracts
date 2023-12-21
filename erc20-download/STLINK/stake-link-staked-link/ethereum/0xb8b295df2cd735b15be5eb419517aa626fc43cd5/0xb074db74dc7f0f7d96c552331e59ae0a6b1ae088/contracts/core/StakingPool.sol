// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "./base/StakingRewardsPool.sol";
import "./interfaces/IStrategy.sol";

/**
 * @title Staking Pool
 * @notice Allows users to stake an asset and receive derivative tokens 1:1, then deposits staked
 * assets into strategy contracts
 */
contract StakingPool is StakingRewardsPool {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct Fee {
        address receiver;
        uint256 basisPoints;
    }

    address[] private strategies;
    uint256 public totalStaked;
    uint256 private liquidityBuffer; // deprecated

    Fee[] private fees;

    address public priorityPool;
    address private delegatorPool; // deprecated
    uint16 private poolIndex; // deprecated

    event UpdateStrategyRewards(address indexed account, uint256 totalStaked, int rewardsAmount, uint256 totalFees);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _token,
        string memory _derivativeTokenName,
        string memory _derivativeTokenSymbol,
        Fee[] memory _fees
    ) public initializer {
        __StakingRewardsPool_init(_token, _derivativeTokenName, _derivativeTokenSymbol);
        for (uint256 i = 0; i < _fees.length; i++) {
            fees.push(_fees[i]);
        }
        require(_totalFeesBasisPoints() <= 5000, "Total fees must be <= 50%");
    }

    modifier onlyPriorityPool() {
        require(priorityPool == msg.sender, "PriorityPool only");
        _;
    }

    /**
     * @notice returns a list of all active strategies
     * @return list of strategies
     */
    function getStrategies() external view returns (address[] memory) {
        return strategies;
    }

    /**
     * @notice returns a list of all fees
     * @return list of fees
     */
    function getFees() external view returns (Fee[] memory) {
        return fees;
    }

    /**
     * @notice stakes asset tokens and mints derivative tokens
     * @param _account account to stake for
     * @param _amount amount to stake
     **/
    function deposit(address _account, uint256 _amount) external onlyPriorityPool {
        require(strategies.length > 0, "Must be > 0 strategies to stake");

        token.safeTransferFrom(msg.sender, address(this), _amount);
        depositLiquidity();

        _mint(_account, _amount);
        totalStaked += _amount;
    }

    /**
     * @notice withdraws asset tokens and burns derivative tokens
     * @dev will withdraw from strategies if not enough liquidity
     * @param _account account to withdraw for
     * @param _receiver address to receive withdrawal
     * @param _amount amount to withdraw
     **/
    function withdraw(
        address _account,
        address _receiver,
        uint256 _amount
    ) external onlyPriorityPool {
        uint256 toWithdraw = _amount;
        if (_amount == type(uint256).max) {
            toWithdraw = balanceOf(_account);
        }

        uint256 balance = token.balanceOf(address(this));
        if (toWithdraw > balance) {
            _withdrawLiquidity(toWithdraw - balance);
        }
        require(token.balanceOf(address(this)) >= toWithdraw, "Not enough liquidity available to withdraw");

        _burn(_account, toWithdraw);
        totalStaked -= toWithdraw;
        token.safeTransfer(_receiver, toWithdraw);
    }

    /**
     * @notice deposits assets into a strategy
     * @param _index index of strategy
     * @param _amount amount to deposit
     **/
    function strategyDeposit(uint256 _index, uint256 _amount) external onlyOwner {
        require(_index < strategies.length, "Strategy does not exist");
        IStrategy(strategies[_index]).deposit(_amount);
    }

    /**
     * @notice withdraws assets from a strategy
     * @param _index index of strategy
     * @param _amount amount to withdraw
     **/
    function strategyWithdraw(uint256 _index, uint256 _amount) external onlyOwner {
        require(_index < strategies.length, "Strategy does not exist");
        IStrategy(strategies[_index]).withdraw(_amount);
    }

    /**
     * @notice returns the maximum amount that can be deposited into the pool
     * @return maximum deposit limit
     **/
    function getMaxDeposits() public view returns (uint256) {
        uint256 max;
        for (uint256 i = 0; i < strategies.length; i++) {
            uint strategyMax = IStrategy(strategies[i]).getMaxDeposits();
            if (strategyMax >= type(uint256).max - max) {
                return type(uint256).max;
            }
            max += strategyMax;
        }
        return max;
    }

    /**
     * @notice returns the minimum amount that must remain the pool
     * @return minimum deposit limit
     */
    function getMinDeposits() public view returns (uint256) {
        uint256 min;

        for (uint256 i = 0; i < strategies.length; i++) {
            IStrategy strategy = IStrategy(strategies[i]);
            min += strategy.getMinDeposits();
        }

        return min;
    }

    /**
     * @notice returns the amont of tokens sitting in this pool outside a strategy
     * @dev these tokens earn no yield and will be deposited ASAP
     * @return amount of tokens outside a strategy
     */
    function getUnusedDeposits() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    /**
     * @notice returns the available deposit room for this pool's strategies
     * @return strategy deposit room
     */
    function getStrategyDepositRoom() external view returns (uint256) {
        uint256 depositRoom;
        for (uint256 i = 0; i < strategies.length; ++i) {
            uint strategyDepositRoom = IStrategy(strategies[i]).canDeposit();
            if (strategyDepositRoom >= type(uint256).max - depositRoom) {
                return type(uint256).max;
            }
            depositRoom += strategyDepositRoom;
        }
        return depositRoom;
    }

    /**
     * @notice returns the available deposit room for this pool
     * @return available deposit room
     */
    function canDeposit() external view returns (uint256) {
        uint256 max = getMaxDeposits();

        if (max <= totalStaked) {
            return 0;
        } else {
            return max - totalStaked;
        }
    }

    /**
     * @notice returns the available withdrawal room for this pool
     * @return available withdrawal room
     */
    function canWithdraw() external view returns (uint256) {
        uint256 min = getMinDeposits();

        if (min >= totalStaked) {
            return 0;
        } else {
            return totalStaked - min;
        }
    }

    /**
     * @notice adds a new strategy
     * @param _strategy address of strategy
     **/
    function addStrategy(address _strategy) external onlyOwner {
        require(!_strategyExists(_strategy), "Strategy already exists");
        token.safeApprove(_strategy, type(uint256).max);
        strategies.push(_strategy);
    }

    /**
     * @notice removes a strategy
     * @param _index index of strategy
     * @param _strategyUpdateData encoded data to be passed to strategy
     **/
    function removeStrategy(uint256 _index, bytes memory _strategyUpdateData) external onlyOwner {
        require(_index < strategies.length, "Strategy does not exist");

        uint256[] memory idxs = new uint256[](1);
        idxs[0] = _index;
        updateStrategyRewards(idxs, _strategyUpdateData);

        IStrategy strategy = IStrategy(strategies[_index]);
        uint256 totalStrategyDeposits = strategy.getTotalDeposits();
        if (totalStrategyDeposits > 0) {
            strategy.withdraw(totalStrategyDeposits);
        }

        for (uint256 i = _index; i < strategies.length - 1; i++) {
            strategies[i] = strategies[i + 1];
        }
        strategies.pop();
        token.safeApprove(address(strategy), 0);
    }

    /**
     * @notice reorders strategies
     * @param _newOrder list containing strategy indexes in a new order
     **/
    function reorderStrategies(uint256[] calldata _newOrder) external onlyOwner {
        require(_newOrder.length == strategies.length, "newOrder.length must = strategies.length");

        address[] memory strategyAddresses = new address[](strategies.length);
        for (uint256 i = 0; i < strategies.length; i++) {
            strategyAddresses[i] = strategies[i];
        }

        for (uint256 i = 0; i < strategies.length; i++) {
            require(strategyAddresses[_newOrder[i]] != address(0), "all indices must be valid");
            strategies[i] = strategyAddresses[_newOrder[i]];
            strategyAddresses[_newOrder[i]] = address(0);
        }
    }

    /**
     * @notice adds a new fee
     * @param _receiver receiver of fee
     * @param _feeBasisPoints fee in basis points
     **/
    function addFee(address _receiver, uint256 _feeBasisPoints) external onlyOwner {
        fees.push(Fee(_receiver, _feeBasisPoints));
        require(_totalFeesBasisPoints() <= 5000, "Total fees must be <= 50%");
    }

    /**
     * @notice updates an existing fee
     * @param _index index of fee
     * @param _receiver receiver of fee
     * @param _feeBasisPoints fee in basis points
     **/
    function updateFee(
        uint256 _index,
        address _receiver,
        uint256 _feeBasisPoints
    ) external onlyOwner {
        require(_index < fees.length, "Fee does not exist");

        if (_feeBasisPoints == 0) {
            fees[_index] = fees[fees.length - 1];
            fees.pop();
        } else {
            fees[_index].receiver = _receiver;
            fees[_index].basisPoints = _feeBasisPoints;
        }

        require(_totalFeesBasisPoints() <= 5000, "Total fees must be <= 50%");
    }

    /**
     * @notice returns the amount of rewards earned since the last update and the amount of fees that
     * will be paid on the rewards
     * @param _strategyIdxs indexes of strategies to sum rewards/fees for
     * @return total rewards
     * @return total fees
     **/
    function getStrategyRewards(uint256[] calldata _strategyIdxs) external view returns (int256, uint256) {
        int256 totalRewards;
        uint256 totalFees;

        for (uint256 i = 0; i < _strategyIdxs.length; i++) {
            IStrategy strategy = IStrategy(strategies[_strategyIdxs[i]]);
            totalRewards += strategy.getDepositChange();
            totalFees += strategy.getPendingFees();
        }

        if (totalRewards > 0) {
            for (uint256 i = 0; i < fees.length; i++) {
                totalFees += (uint256(totalRewards) * fees[i].basisPoints) / 10000;
            }
        }

        if (totalFees >= totalStaked) {
            totalFees = 0;
        }

        return (totalRewards, totalFees);
    }

    /**
     * @notice updates and distributes rewards based on balance changes in strategies
     * @param _strategyIdxs indexes of strategies to update rewards for
     * @param _data encoded data to be passed to each strategy
     **/
    function updateStrategyRewards(uint256[] memory _strategyIdxs, bytes memory _data) public {
        int256 totalRewards;
        uint256 totalFeeAmounts;
        uint256 totalFeeCount;
        address[][] memory receivers = new address[][](strategies.length + 1);
        uint256[][] memory feeAmounts = new uint256[][](strategies.length + 1);

        for (uint256 i = 0; i < _strategyIdxs.length; ++i) {
            IStrategy strategy = IStrategy(strategies[_strategyIdxs[i]]);

            (int256 depositChange, address[] memory strategyReceivers, uint256[] memory strategyFeeAmounts) = strategy
                .updateDeposits(_data);
            totalRewards += depositChange;

            if (strategyReceivers.length != 0) {
                receivers[i] = strategyReceivers;
                feeAmounts[i] = strategyFeeAmounts;
                totalFeeCount += receivers[i].length;
                for (uint256 j = 0; j < strategyReceivers.length; ++j) {
                    totalFeeAmounts += strategyFeeAmounts[j];
                }
            }
        }

        if (totalRewards != 0) {
            totalStaked = uint256(int256(totalStaked) + totalRewards);
        }

        if (totalRewards > 0) {
            receivers[receivers.length - 1] = new address[](fees.length);
            feeAmounts[feeAmounts.length - 1] = new uint256[](fees.length);
            totalFeeCount += fees.length;

            for (uint256 i = 0; i < fees.length; i++) {
                receivers[receivers.length - 1][i] = fees[i].receiver;
                feeAmounts[feeAmounts.length - 1][i] = (uint256(totalRewards) * fees[i].basisPoints) / 10000;
                totalFeeAmounts += feeAmounts[feeAmounts.length - 1][i];
            }
        }

        if (totalFeeAmounts >= totalStaked) {
            totalFeeAmounts = 0;
        }

        if (totalFeeAmounts > 0) {
            uint256 sharesToMint = (totalFeeAmounts * totalShares) / (totalStaked - totalFeeAmounts);
            _mintShares(address(this), sharesToMint);

            uint256 feesPaidCount;
            for (uint256 i = 0; i < receivers.length; i++) {
                for (uint256 j = 0; j < receivers[i].length; j++) {
                    if (feesPaidCount == totalFeeCount - 1) {
                        transferAndCallFrom(address(this), receivers[i][j], balanceOf(address(this)), "0x");
                    } else {
                        transferAndCallFrom(address(this), receivers[i][j], feeAmounts[i][j], "0x");
                        feesPaidCount++;
                    }
                }
            }
        }

        emit UpdateStrategyRewards(msg.sender, totalStaked, totalRewards, totalFeeAmounts);
    }

    /**
     * @notice deposits available liquidity into strategies by order of priority
     * @dev deposits into strategies[0] until its limit is reached, then strategies[1], and so on
     **/
    function depositLiquidity() public {
        uint256 toDeposit = token.balanceOf(address(this));
        if (toDeposit > 0) {
            for (uint256 i = 0; i < strategies.length; i++) {
                IStrategy strategy = IStrategy(strategies[i]);
                uint256 strategyCanDeposit = strategy.canDeposit();
                if (strategyCanDeposit >= toDeposit) {
                    strategy.deposit(toDeposit);
                    break;
                } else if (strategyCanDeposit > 0) {
                    strategy.deposit(strategyCanDeposit);
                    toDeposit -= strategyCanDeposit;
                }
            }
        }
    }

    /**
     * @notice Sets the priority pool
     * @param _priorityPool address of priority pool
     **/
    function setPriorityPool(address _priorityPool) external onlyOwner {
        priorityPool = _priorityPool;
    }

    /**
     * @notice returns the total amount of assets staked in the pool
     * @return the total staked amount
     */
    function _totalStaked() internal view override returns (uint256) {
        return totalStaked;
    }

    /**
     * @notice withdraws liquidity from strategies in opposite order of priority
     * @dev withdraws from strategies[strategies.length - 1], then strategies[strategies.length - 2], and so on
     * until withdraw amount is reached
     * @param _amount amount to withdraw
     **/
    function _withdrawLiquidity(uint256 _amount) private {
        uint256 toWithdraw = _amount;

        for (uint256 i = strategies.length; i > 0; i--) {
            IStrategy strategy = IStrategy(strategies[i - 1]);
            uint256 strategyCanWithdrawdraw = strategy.canWithdraw();

            if (strategyCanWithdrawdraw >= toWithdraw) {
                strategy.withdraw(toWithdraw);
                break;
            } else if (strategyCanWithdrawdraw > 0) {
                strategy.withdraw(strategyCanWithdrawdraw);
                toWithdraw -= strategyCanWithdrawdraw;
            }
        }
    }

    /**
     * @notice returns the sum of all fees
     * @return sum of fees in basis points
     **/
    function _totalFeesBasisPoints() private view returns (uint256) {
        uint256 totalFees;
        for (uint i = 0; i < fees.length; i++) {
            totalFees += fees[i].basisPoints;
        }
        return totalFees;
    }

    /**
     * @notice checks whether or not a strategy exists
     * @param _strategy address of strategy
     * @return true if strategy exists, false otherwise
     **/
    function _strategyExists(address _strategy) private view returns (bool) {
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i] == _strategy) {
                return true;
            }
        }
        return false;
    }
}
