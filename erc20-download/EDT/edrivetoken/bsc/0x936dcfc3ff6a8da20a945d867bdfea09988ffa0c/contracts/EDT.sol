// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./EDT_RewardToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";


/**
 * @title EdriveToken
 * @author Niccolo' Petti
 * @dev A token with variable fees depending on the NFT held by the user
 * fees accumulated and swapped for WBNB and redistributed to all holders 
 * using ERC2222 (Funds Distribution Token), more details on EDT at https://www.edrivetoken.io/
*/
contract EdriveToken is ERC20, Ownable {
    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;
    address private immutable WETH;
    EDT_RewardToken public immutable rewardTracker;

    IERC1155 public immutable vipStatus;

    uint128 public swapTokensAtAmount;

    //antisnipers
    uint64 public liqAddedBlockNumber;
    uint64 public constant blocksToWait = 2;

    event ExcludedFromFees(address indexed account);
    event ExcludeFromFeeReduction(address indexed account);
    event ExcludedFromMaxAmount(address indexed account);
    event ExcludedFromNumTx(address indexed account);
    event ExcludeFromBlacklist(address account);
    event ExcludeFromAMMPair(address account);

    event IncludeInFees(address indexed account);
    event IncludeInFeeReduction(address indexed account);
    event IncludeInMaxAmount(address indexed account);
    event IncludeInNumTx(address indexed account);
    event IncludeInBlacklist(address account);
    event IncludeInAMMPair(address account);
    event SwapTokensAtAmountUpdated(uint128 amount);
    event DailyLimitsUpdated(uint128 amount, uint64 numTx);

    event SetIsAutomatedMarketMakerPair(
        address indexed pair,
        bool indexed value
    );

    struct feeRatesStruct {
        uint32 diamond;
        uint32 gold;
        uint32 silver;
        uint32 bronze;
        uint32 none;
    }

    struct status {
        bool isExcludedFromFees;
        bool isAutomatedMarketMakerPair;
        bool isExcludedFromMaxAmount;
        bool isExcludedFromNumTx;
        bool isBlacklisted;
    }

    mapping(address => status) public statuses;

    struct txTracker {
        uint128 amount;
        uint64 numTx;
        uint64 last_timestamp;
    }

    txTracker public dailyLimits;

    feeRatesStruct public statusFees =
        feeRatesStruct({
            diamond: 0,
            gold: 15,
            silver: 30,
            bronze: 45,
            none: 60
        });

    mapping(address => txTracker) public last_txs;

    constructor(IUniswapV2Router02 _uniswapV2Router, IERC1155 _vipStatus)
        ERC20("EDriveToken", "EDT")
    {
        WETH = _uniswapV2Router.WETH();
        // Create a uniswap pair for this new token
        address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), WETH);

        rewardTracker = new EDT_RewardToken(
            "EDT_RewardToken",
            "EDT_RewardToken",
            IERC20(WETH)
        );
        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = _uniswapV2Pair;
        statuses[_uniswapV2Pair].isAutomatedMarketMakerPair = true;
        emit IncludeInAMMPair(_uniswapV2Pair);

        _approve(address(this), address(_uniswapV2Router), type(uint256).max);

        // exclude from receiving rewards
        rewardTracker.setIsExcludedFromRewards(address(this), true);
        rewardTracker.setIsExcludedFromRewards(_uniswapV2Pair, true);

        // exclude from paying fees or having max transaction amount
        setIsExcludedFromFees(msg.sender, true);
        setIsExcludedFromFees(address(this), true);
        setIsExcludedFromMaxAmount(msg.sender, true);
        setIsExcludedFromMaxAmount(address(this), true);

        uint128 totSupply = 20 * 10**9 * (10**18);
        _mint(msg.sender, totSupply);
        rewardTracker.setBalance(msg.sender, totSupply);
        dailyLimits.numTx = 10;
        dailyLimits.amount = totSupply / 1000;

        swapTokensAtAmount = totSupply / 10000; //0.01% 2M tokens
        vipStatus = _vipStatus;
    }

    function setIsExcludedFromFees(address account, bool toExclude)
        public
        onlyOwner
    {
        require(
            statuses[account].isExcludedFromFees != toExclude,
            "Account has already that status for fees"
        );
        statuses[account].isExcludedFromFees = toExclude;
        if (toExclude) {
            emit ExcludedFromFees(account);
        } else {
            emit IncludeInFees(account);
        }
    }

    function setIsAutomatedMarketMakerPair(address pair, bool value)
        external
        onlyOwner
    {
        require(
            statuses[pair].isAutomatedMarketMakerPair != value,
            "Account has already that status for AMM pair"
        );
        require(pair != uniswapV2Pair, "EDT-BNB must be an AMM pair");

        statuses[pair].isAutomatedMarketMakerPair = value;

        if (value) {
            emit IncludeInAMMPair(pair);
        } else {
            emit ExcludeFromAMMPair(pair);
        }
    }

    function setIsExcludedFromMaxAmount(address account, bool toExclude)
        public
        onlyOwner
    {
        require(
            statuses[account].isExcludedFromMaxAmount != toExclude,
            "Account has already that status for MaxAmount"
        );
        statuses[account].isExcludedFromMaxAmount = toExclude;
        if (toExclude) {
            emit ExcludedFromMaxAmount(account);
        } else {
            emit IncludeInMaxAmount(account);
        }
    }

    function setIsExcludedFromNumTx(address account, bool toExclude)
        public
        onlyOwner
    {
        require(
            statuses[account].isExcludedFromNumTx != toExclude,
            "Account has already that status for NumTx"
        );
        statuses[account].isExcludedFromNumTx = toExclude;
        if (toExclude) {
            emit ExcludedFromNumTx(account);
        } else {
            emit IncludeInNumTx(account);
        }
    }

    function setIsBlacklisted(address user, bool toBeBlacklisted)
        external
        onlyOwner
    {
        require(
            statuses[user].isBlacklisted != toBeBlacklisted,
            "Account has already that status for blacklist"
        );
        _setIsBlacklisted(user, toBeBlacklisted);
    }

    function setIsExcludedFromRewards(address account, bool toExclude)
        external
        onlyOwner
    {
        rewardTracker.setIsExcludedFromRewards(account, toExclude);
    }

    function setNFTFees(uint32 diamond,uint32 gold,uint32 silver,uint32 bronze,uint32 none)
        external
        onlyOwner
    {
        require(none<=200,"Fees can't exceed 20%");
        require(diamond<=gold && gold<=silver && silver<=bronze && bronze<=none, "privileges not respected");
        statusFees.diamond=diamond;
        statusFees.gold=gold;
        statusFees.silver=silver;
        statusFees.bronze=bronze;
        statusFees.none=none;
    }

    function setSwapTokensAtAmount(uint128 _swapTokensAtAmount)
        external
        onlyOwner
    {
        swapTokensAtAmount = _swapTokensAtAmount;
        emit SwapTokensAtAmountUpdated(_swapTokensAtAmount);
    }

    function setDailyLimits(uint128 _amount, uint64 _numTx) external onlyOwner {
        dailyLimits.amount = _amount;
        dailyLimits.numTx = _numTx;
        emit DailyLimitsUpdated(_amount, _numTx);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        status memory statusFrom = statuses[from];
        require(!statusFrom.isBlacklisted, "from is a blacklisted address");
        status memory statusTo = statuses[to];
        require(!statusTo.isBlacklisted, "to is a blacklisted address");

        if (liqAddedBlockNumber == 0 && statusTo.isAutomatedMarketMakerPair) {
            liqAddedBlockNumber = uint64(block.number);
        }

        txTracker memory limit = dailyLimits;
        if (!statusFrom.isAutomatedMarketMakerPair) {
            //>1 day since last tx
            if (block.timestamp > last_txs[from].last_timestamp + 1 days) {
                last_txs[from].amount = uint128(amount);
                last_txs[from].numTx = 1;
            } else {
                last_txs[from].amount = uint128(last_txs[from].amount + amount);
                unchecked {
                    ++last_txs[from].numTx;
                }
            }

            require(
                statusFrom.isExcludedFromMaxAmount ||
                    last_txs[from].amount <= limit.amount,
                "Sell transfer amount exceeds the maxSellTransactionAmount."
            );

            last_txs[from].last_timestamp = uint64(block.timestamp);

            if (
                balanceOf(address(this)) >= swapTokensAtAmount &&
                from != address(this)
            ) {
                swapTokensForRewards(swapTokensAtAmount);
            }
        }

        if (!statusFrom.isExcludedFromFees && !statusTo.isExcludedFromFees) {
            address target = statusFrom.isAutomatedMarketMakerPair ? to : from;
            if (
                block.number < liqAddedBlockNumber + blocksToWait &&
                statusFrom.isAutomatedMarketMakerPair !=
                statusTo.isAutomatedMarketMakerPair
            ) {
                _setIsBlacklisted(target, true);
            }

            uint256 deducted_fees = (getTransferFees(target,statusFrom.isAutomatedMarketMakerPair) * amount) / 1000;
            if (deducted_fees != 0) {
                amount -= deducted_fees;
                super._transfer(from, address(this), deducted_fees);
            }
        }
        super._transfer(from, to, amount);
        rewardTracker.setBalance(from, balanceOf(from));
        rewardTracker.setBalance(to, balanceOf(to));
    }

    function swapTokensForRewards(uint128 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WETH;

        // make the swap
        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(rewardTracker),
            block.timestamp
        );
        rewardTracker.updateFundsReceived();
    }

    function _setIsBlacklisted(address user, bool toBeBlacklisted) private {
        statuses[user].isBlacklisted = toBeBlacklisted;
        if (toBeBlacklisted) {
            emit ExcludeFromBlacklist(user);
        } else {
            emit IncludeInBlacklist(user);
        }
        rewardTracker.setIsExcludedFromRewards(user, toBeBlacklisted);
    }

    function getTransferFees(address target, bool bypassCheck) public view returns (uint256) {
        if (
            target.code.length == 0 &&
            (   bypassCheck ||
                statuses[target].isExcludedFromNumTx ||
                last_txs[target].numTx <= dailyLimits.numTx)
        ) {
            if (vipStatus.balanceOf(target, 0) != 0) {
                return statusFees.diamond;
            } else if (vipStatus.balanceOf(target, 1) != 0) {
                return statusFees.gold;
            } else if (vipStatus.balanceOf(target, 2) != 0) {
                return statusFees.silver;
            } else if (vipStatus.balanceOf(target, 3) != 0) {
                return statusFees.bronze;
            }
        }
        return statusFees.none;
    }
}
