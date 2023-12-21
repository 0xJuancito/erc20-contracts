/*
 * Twitter: https://twitter.com/yoyomarket_io
 * Website: https://www.yoyomarket.io/
 * Main Telegram: https://t.me/yoyomarket_portal
 * Announcements: https://t.me/yoyomarketann
 * Medium: https://medium.com/@yoyomarket/
 */

// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.20;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IUniswapV2Router02} from '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import {IUniswapV2Factory} from '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';

contract YOYO is ERC20, Ownable {
	/* Constants */

	uint256 public constant TOTAL_SUPPLY = 100_000_000e18; // 100m
	uint256 public constant LIQUIDITY_SUPPLY_AMOUNT = (TOTAL_SUPPLY * 80) / 100; // 80%

	uint256 private constant FEE_DENOMINATOR = 10000;

	uint256 private constant LAUNCH_DURATION = 5 minutes;

	uint256 private constant LAUNCH_BUY_FEE = (FEE_DENOMINATOR * 35) / 100; // 35%
	uint256 private constant LAUNCH_SELL_FEE = (FEE_DENOMINATOR * 35) / 100; // 35%

	uint256 private constant AFTER_LAUNCH_BUY_FEE = (FEE_DENOMINATOR * 4) / 100; // 4%
	uint256 private constant AFTER_LAUNCH_SELL_FEE = (FEE_DENOMINATOR * 4) / 100; // 4%

	uint256 private constant LAUNCH_MAX_WALLET_AMOUNT = TOTAL_SUPPLY / 1000; // 0.1%
	uint256 private constant INITAL_AFTER_LAUNCH_MAX_WALLET_AMOUNT = (TOTAL_SUPPLY * 5) / 1000; // 0.5%
	uint256 private constant FINAL_AFTER_LAUNCH_MAX_WALLET_AMOUNT = type(uint256).max;

	uint256 private constant FEE_FOR_TEAM = (FEE_DENOMINATOR * 40) / 100; // 40%
	uint256 private constant FEE_FOR_STAKING = (FEE_DENOMINATOR * 40) / 100; // 40%

	uint256 private constant DEFAULT_MINIMUM_ACCUMULATED_FEE_TO_SWAP = (TOTAL_SUPPLY * 1) / 100;

	IUniswapV2Router02 private constant UNISWAP_V2_ROUTER = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
	IUniswapV2Factory private constant UNISWAP_V2_FACTORY = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
	address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

	address public immutable PAIR;
	uint256 public immutable LAUNCH_END_TIMESTAMP;

	/* Storage */

	mapping(address => bool) private _exemptFromSwapFees;
	mapping(address => bool) private _exemptFromMaxAmount;

	uint256 private _afterLaunchMaxWalletAmount = INITAL_AFTER_LAUNCH_MAX_WALLET_AMOUNT;

	uint256 private _minimumAcculumatedFeeToSwap = DEFAULT_MINIMUM_ACCUMULATED_FEE_TO_SWAP;

	address public treasuryFeeWallet = 0xBDF0D25341f0726BF86771340012AF7B04D58d3c;
	address public stakingFeeWallet = 0x7f16667aCC6B1AB545841e70e27F7F4058234ab3;
	address public lpFeeWallet = 0x9AF3ABea69E8d0C03912f4abFA969b5F8482db2c;

	/* Constructor */

	constructor() ERC20('YOYO', 'YOYO') {
		PAIR = UNISWAP_V2_FACTORY.createPair(address(this), WETH);

		_exemptFromSwapFees[msg.sender] = true;
		_exemptFromSwapFees[address(this)] = true;

		_exemptFromMaxAmount[msg.sender] = true;
		_exemptFromMaxAmount[address(this)] = true;
		_exemptFromMaxAmount[PAIR] = true;
		_exemptFromMaxAmount[treasuryFeeWallet] = true;
		_exemptFromMaxAmount[stakingFeeWallet] = true;
		_exemptFromMaxAmount[lpFeeWallet] = true;

		LAUNCH_END_TIMESTAMP = block.timestamp + LAUNCH_DURATION;

		_mint(msg.sender, TOTAL_SUPPLY);
		_approve(address(this), address(UNISWAP_V2_ROUTER), type(uint256).max);
	}

	/* Non-View Functions */

	function swapTeamFees() public {
		uint256 amount = balanceOf(address(this));

		address[] memory path = new address[](2);
		path[0] = address(this);
		path[1] = WETH;

		UNISWAP_V2_ROUTER.swapExactTokensForTokens(
			(amount * FEE_FOR_TEAM) / FEE_DENOMINATOR,
			0,
			path,
			treasuryFeeWallet,
			block.timestamp
		);

		super._transfer(address(this), stakingFeeWallet, (amount * FEE_FOR_STAKING) / FEE_DENOMINATOR);

		super._transfer(address(this), lpFeeWallet, balanceOf(address(this)));
	}

	function burn(address account, uint256 amount) external {
		_spendAllowance(account, msg.sender, amount);
		_burn(account, amount);
	}

	function burn(uint256 amount) external {
		_burn(msg.sender, amount);
	}

	function transferMany(address[] calldata accounts, uint256[] calldata amounts) external {
		if (accounts.length != amounts.length) revert();

		uint256 len = accounts.length;

		for (uint256 i = 0; i < len; ) {
			super._transfer(msg.sender, accounts[i], amounts[i]);
			unchecked {
				++i;
			}
		}
	}

	/* View Functions */

	function fees() public view returns (uint256 buyFee, uint256 sellFee) {
		if (block.timestamp < LAUNCH_END_TIMESTAMP) {
			/* During launch period */
			return (LAUNCH_BUY_FEE, LAUNCH_SELL_FEE);
		}

		/* After launch period */
		return (AFTER_LAUNCH_BUY_FEE, AFTER_LAUNCH_SELL_FEE);
	}

	function maxWalletAmount() external view returns (uint256) {
		if (block.timestamp < LAUNCH_END_TIMESTAMP) {
			/* During launch period */
			return LAUNCH_MAX_WALLET_AMOUNT;
		}

		/* After launch period */
		return _afterLaunchMaxWalletAmount;
	}

	/* Owner Only Functions */

	function addInitialLiquidity() public payable onlyOwner {
		super._transfer(msg.sender, address(this), LIQUIDITY_SUPPLY_AMOUNT);

		UNISWAP_V2_ROUTER.addLiquidityETH{value: msg.value}(
			address(this),
			LIQUIDITY_SUPPLY_AMOUNT,
			0,
			0,
			msg.sender,
			block.timestamp
		);

		if (address(this).balance > 0 || balanceOf(address(this)) > 0) {
			revert('REMAINING_BALANCE');
		}
	}

	function finalizeMaxAmountPerWallet() external onlyOwner {
		_afterLaunchMaxWalletAmount = FINAL_AFTER_LAUNCH_MAX_WALLET_AMOUNT;
	}

	function changeSwapThreshold(uint256 minimumAcculumatedFeeToSwap) external onlyOwner {
		_minimumAcculumatedFeeToSwap = minimumAcculumatedFeeToSwap;
	}

	function changeWallets(address _treasuryFeeWallet, address _stakingFeeWallet, address _lpFeeWallet) public payable onlyOwner {
		if (_afterLaunchMaxWalletAmount != FINAL_AFTER_LAUNCH_MAX_WALLET_AMOUNT) revert();

		treasuryFeeWallet = _treasuryFeeWallet;
		stakingFeeWallet = _stakingFeeWallet;
		lpFeeWallet = _lpFeeWallet;
	}

	/* Overrides */

	function _transfer(address sender, address recipient, uint256 amount) internal override {
		uint256 feePercentage = 0;

		if (sender == PAIR) {
			/* Is in a buy */
			if (_exemptFromSwapFees[recipient] == false) {
				/* Is in a taxable buy */
				if (block.timestamp < LAUNCH_END_TIMESTAMP) {
					/* During launch period */
					feePercentage = LAUNCH_BUY_FEE;
				} else {
					/* After launch period */
					feePercentage = AFTER_LAUNCH_BUY_FEE;
				}
			}
		} else {
			if (sender != address(this) && balanceOf(address(this)) >= _minimumAcculumatedFeeToSwap) {
				swapTeamFees();
			}

			if (recipient == PAIR && _exemptFromSwapFees[sender] == false) {
				/* Is in a taxable sell */
				if (block.timestamp < LAUNCH_END_TIMESTAMP) {
					/* During launch period */
					feePercentage = LAUNCH_SELL_FEE;
				} else {
					/* After launch period */
					feePercentage = AFTER_LAUNCH_SELL_FEE;
				}
			}
		}

		uint256 feeAmount = (amount * feePercentage) / FEE_DENOMINATOR;
		amount -= feeAmount;

		super._transfer(sender, recipient, amount);

		if (feeAmount > 0) {
			super._transfer(sender, address(this), feeAmount);
		}
	}

	function _beforeTokenTransfer(address, address to, uint256 amount) internal view override {
		if (block.timestamp < LAUNCH_END_TIMESTAMP) {
			/* During launch period */
			if (balanceOf(to) + amount > LAUNCH_MAX_WALLET_AMOUNT && _exemptFromMaxAmount[to] == false) {
				revert('MAX_WALLET_AMOUNT');
			}
		} else {
			/* After launch period */
			if (balanceOf(to) + amount > _afterLaunchMaxWalletAmount && _exemptFromMaxAmount[to] == false) {
				revert('MAX_WALLET_AMOUNT');
			}
		}
	}
}
