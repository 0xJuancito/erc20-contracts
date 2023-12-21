// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

/*
    _    _  ___  _   _ _   _ ____
   | \  / |/ _ \| | | | \ | |  _ \
   | |\/| | | | | | | |  \| | | | \
   | |  | | |_| | |_| | |\  | |_| /
   |_|  |_|\___/ \___/|_| \_|____/


*
* MIT License
* ===========
*
* Copyright (c) 2021 MOUND FINANCE
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*/

import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol";

import "./interfaces/IMoundToken.sol";
import "./interfaces/IPriceCalculator.sol";
import "./interfaces/IRewardPool.sol";
import "./interfaces/IStrategyPayable.sol";
import "./library/BEP20Upgradeable.sol";
import "./library/SafeToken.sol";

contract MoundTokenBSC is IMoundToken, BEP20Upgradeable {
    using SafeToken for address;
    using SafeBEP20 for IBEP20;

    /* ========== CONSTANT ========== */

    IPriceCalculator public constant priceCalculator = IPriceCalculator(0xF5BF8A9249e3cc4cB684E3f23db9669323d4FB7d);
    IRewardPool public constant MND_VAULT = IRewardPool(0x7a7f11ef54fD7ce28808ec3F0C4178aFDfc91493);

    uint public constant RESERVE_RATIO = 15;
    address public constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    uint private constant BOUNTY_BASE = 10000;
    uint private constant HARVEST_BOUNTY_RATIO = 5;

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    /* ========== STATE VARIABLES ========== */

    mapping(address => bool) public minters;

    address[] private _portfolioList;
    mapping(address => PortfolioInfo) public portfolios;

    address public keeper;

    mapping(address => uint) private _profitSupply;
    mapping(address => uint) public pendingRewards; // rewardToken => amount

    uint256 private _status = _NOT_ENTERED;

    /* ========== EVENTS ========== */

    event Deposited(address indexed user, address indexed token, uint amount);

    receive() external payable {}

    /* ========== MODIFIERS ========== */

    modifier onlyMinter() {
        require(owner() == msg.sender || minters[msg.sender], "MoundToken: caller is not the minter");
        _;
    }

    modifier onlyKeeper() {
        require(keeper == msg.sender || owner() == msg.sender, "MoundToken: caller is not keeper");
        _;
    }

    modifier nonReentrant {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /* ========== INITIALIZER ========== */

    function initialize() external initializer {
        __BEP20__init("Mound Token", "MND", 18);
    }

    /* ========== VIEWS ========== */

    function tvl() public view override returns (uint valueInUSD) {
        valueInUSD = 0;

        for (uint i = 0; i < _portfolioList.length; i++) {
            valueInUSD = valueInUSD.add(portfolioValueOf(_portfolioList[i]));
        }
    }

    function portfolioValueOf(address token) public view returns (uint) {
        uint rewardBalance = IStrategy(portfolios[token].strategy).earned(address(this));

        (, uint rewardValue) = priceCalculator.valueOfAsset(portfolios[token].token, rewardBalance);
        (, uint stakedValue) = priceCalculator.valueOfAsset(token, portfolioBalanceOf(token));

        return rewardValue.add(stakedValue);
    }

    function portfolioBalanceOf(address token) public view returns (uint) {
        uint stakedBalance = portfolios[token].strategy == address(0)
        ? 0
        : IStrategy(portfolios[token].strategy).balanceOf(address(this));
        return stakedBalance;
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function mint(address account, uint amount) public override onlyMinter {
        _mint(account, amount);
        _mint(owner(), amount.mul(RESERVE_RATIO).div(100));
    }

    function setMinter(address account, bool isMinter) external onlyOwner {
        minters[account] = isMinter;
    }

    function setKeeper(address _keeper) external onlyOwner {
        require(_keeper != address(0), "MoundToken: invalid address");
        keeper = _keeper;
    }

    function addPortfolio(address stakingToken, address rewardToken, address strategy) external override onlyOwner {
        require(portfolios[stakingToken].token == address(0), "MoundToken: portfolio is already set");
        portfolios[stakingToken] = PortfolioInfo(rewardToken, strategy);
        _portfolioList.push(stakingToken);

        if (stakingToken != WBNB && strategy != address(0)) {
            IBEP20(stakingToken).safeApprove(strategy, 0);
            IBEP20(stakingToken).safeApprove(strategy, uint(- 1));
        }
    }

    function initializePortfolio(address stakingToken, address rewardToken, address strategy) external onlyOwner {
        require(portfolios[stakingToken].token != address(0), "MoundToken: portfolio is not set");
        portfolios[stakingToken] = PortfolioInfo(rewardToken, strategy);

        if (stakingToken != WBNB && strategy != address(0)) {
            IBEP20(stakingToken).safeApprove(strategy, 0);
            IBEP20(stakingToken).safeApprove(strategy, uint(- 1));
        }
    }

    function updatePortfolioStrategy(address token, address strategy) external override onlyOwner {
        require(strategy != address(0), "MoundToken: strategy must not be zero");
        require(token != address(0), "MoundToken: token must not be zero");
        uint _before = IBEP20(token).balanceOf(address(this));
        if (portfolios[token].strategy != address(0) && IStrategy(portfolios[token].strategy).balanceOf(address(this)) > 0) {
            IStrategy(portfolios[token].strategy).withdrawAll();
        }
        uint migrationAmount = IBEP20(token).balanceOf(address(this)).sub(_before);
        if (portfolios[token].strategy != address(0)) {
            IBEP20(token).approve(portfolios[token].strategy, 0);
        }

        portfolios[token].strategy = strategy;

        IBEP20(token).safeApprove(strategy, 0);
        IBEP20(token).safeApprove(strategy, uint(- 1));

        if (migrationAmount > 0) {
            IStrategyPayable(strategy).deposit(migrationAmount);
        }
    }

    function harvest() public nonReentrant returns(uint bounty) {
        address[] memory rewardTokens = MND_VAULT.rewardTokens();    // BUNNY, QBT, (WBNB)
        uint[] memory amounts = new uint[](rewardTokens.length);

        for (uint i = 0; i < _portfolioList.length; i++) {
            if (portfolios[_portfolioList[i]].strategy != address(0)) {
                address rewardToken = portfolios[_portfolioList[i]].token;
                uint beforeBalance = rewardToken == WBNB ? address(this).balance : IBEP20(rewardToken).balanceOf(address(this));

                if (IStrategy(portfolios[_portfolioList[i]].strategy).earned(address(this)) > 0) {
                    IStrategy(portfolios[_portfolioList[i]].strategy).getReward();
                }

                uint afterBalance = rewardToken == WBNB ? address(this).balance : IBEP20(rewardToken).balanceOf(address(this));
                pendingRewards[rewardToken] = pendingRewards[rewardToken].add(afterBalance.sub(beforeBalance));
            }
        }

        for (uint i = 0; i < rewardTokens.length; i++) {
            address rewardToken = rewardTokens[i];

            uint profit = pendingRewards[rewardToken].add(_profitSupply[rewardToken]);
            pendingRewards[rewardToken] = 0;
            _profitSupply[rewardToken] = 0;

            if (profit > 0) {
                if (rewardToken == WBNB) {
                    bounty = profit.mul(HARVEST_BOUNTY_RATIO).div(BOUNTY_BASE);
                    profit = profit.sub(bounty);
                    SafeToken.safeTransferETH(address(MND_VAULT), profit);
                    SafeToken.safeTransferETH(msg.sender, bounty);
                } else {
                    IBEP20(rewardToken).safeTransfer(address(MND_VAULT), profit);
                }
            }
            amounts[i] = profit;
        }

        MND_VAULT.notifyRewardAmounts(amounts);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function deposit(address token, uint amount) external payable override onlyKeeper {
        if (token == WBNB) {
            amount = msg.value;
            if (portfolios[token].strategy != address(0)) {
                IStrategyPayable(portfolios[token].strategy).deposit{value : amount}(amount);
            }
        } else {
            IBEP20(token).safeTransferFrom(msg.sender, address(this), amount);
            if (portfolios[token].strategy != address(0)) {
                IStrategyPayable(portfolios[token].strategy).deposit(amount);
            }
        }

        emit Deposited(msg.sender, token, amount);
    }

    function depositRest(address token, uint amount) external onlyKeeper {
        if (portfolios[token].strategy != address(0)) {
            if (IBEP20(token).balanceOf(address(this)) >= amount) {
                IStrategyPayable(portfolios[token].strategy).deposit(amount);
            }
        }
    }
}
