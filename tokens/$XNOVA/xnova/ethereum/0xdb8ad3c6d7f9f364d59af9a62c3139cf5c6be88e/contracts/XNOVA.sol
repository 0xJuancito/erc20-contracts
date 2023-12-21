// SPDX-License-Identifier: MIT
/*
	TG:           https://t.me/+ZkNmt_AdyOA5ZDQ1
	Twitter:      https://twitter.com/xnovatoken
	Website:      https://xnova.io/
	Certik Audit: https://skynet.certik.com/projects/xnova
*/
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/UniswapInterface.sol";

/**
 * XNOVA smart contract
 * @author XNOVA Team
 */

contract XNOVA is ERC20, Ownable {
	//
	// State Variables
	//

	bool private swapping;
	bool public disableFees;
	bool public tradingEnabled = false;
	bool public transferDelayEnabled = false; // Delay at launch

	mapping(address => bool) private _isExcludedFromFee;

	// store addresses that are automatic market maker pairs. Any transfer *to* these addresses
	// could be subject to a maximum transfer amount
	mapping(address => bool) public automatedMarketMakerPairs;
	mapping(address => uint256) private lastTransactionTime;

	// Whitelisted Wallets are excluded from trading restrictions
	// Blacklisted wallets are excluded from token transfers & swaps
	mapping(address => bool) public whiteList;
	mapping(address => bool) public blackList;

	IUniswapV2Router02 public uniswapV2Router;
	address public immutable uniswapV2Pair;

	address private constant revenuewallet =
		0x29ec31DE62a243b7f815F62D7Eec3E6C8b21fe7E;
	address private constant teamwallet =
		0x93642B8425054f4C6a6368Ee621FA3B8deD40a36;
	address private constant treasurywallet =
		0xcF9E20DC69285d8952d6c1dee5F02541b3C9BCAd;

	uint256 public maxSellTransactionAmount = 50000 * 1e18; // 0.5% of total supply 10M
	uint256 public maxBuyTransactionAmount = 200000 * 1e18; // 2% of total supply 10M
	uint256 public swapTokensAtAmount = 25000 * 1e18;

	uint256 private constant feeUnits = 1000; // 1000 represents 100%
	uint256 public standardFee = 300; // 4% buy fees , 30% at launch
	uint256 public revenueFee = 150; // 2% to revenuewallet, 15% at launch
	uint256 public treasuryFee = 150; // 2% to treasurywallet, 15% at launch

	uint256 public tradingEnabledTimestamp;
	uint256 public trasferDelay = 15 minutes; // 15 mins at launch

	//
	// Events:
	//

	event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
	event SwapAndDistributeFee(uint256 tokenAmount, address recipient);

	//
	// Constructor:
	//

	constructor() ERC20("XNOVA", "XNOVA") {
		IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
			0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D // UniswapV2Router02
		);
		address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
			.createPair(address(this), _uniswapV2Router.WETH());

		uniswapV2Router = _uniswapV2Router;
		uniswapV2Pair = _uniswapV2Pair;

		// Exclude from fees
		_isExcludedFromFee[address(this)] = true;
		_isExcludedFromFee[treasurywallet] = true;
		_isExcludedFromFee[revenuewallet] = true;
		_isExcludedFromFee[teamwallet] = true;
		_isExcludedFromFee[owner()] = true;

		_setAutomatedMarketMakerPair(_uniswapV2Pair, true);

		_mint(owner(), 10000000 * 1e18); // 10 Million tokens
		tradingEnabledTimestamp = block.timestamp + 2 days;
	}

	receive() external payable {}

	/**
	 * Function that allows only the owner to enable and disable trading
	 */

	function setTradingEnabled(bool _enabled) external onlyOwner {
		tradingEnabled = _enabled;
	}

	function setTransferDelayEnabled(bool _enabled) external onlyOwner {
		transferDelayEnabled = _enabled;
	}

	/**
	 * Function that allows only the owner to exclude an address from fees
	 */

	function excludeFromFee(address _address) external onlyOwner {
		_isExcludedFromFee[_address] = true;
	}

	/**
	 * Function that allows only the owner to include an address to fees
	 */
	function includeToFee(address _address) external onlyOwner {
		_isExcludedFromFee[_address] = false;
	}

	/**
	 * Function that allows only the owner set time to start trading
	 */
	function setTradingEnabledTimestamp(uint256 timestamp) external onlyOwner {
		tradingEnabledTimestamp = timestamp;
	}

	/**
	 * Function that allows only the owner to disable buy and sell fees
	 */
	function updateDisableFees(bool _disableFees) external onlyOwner {
		if (_disableFees) {
			_removeDust();
		}
		disableFees = _disableFees;
	}

	/**
	 * Function that allows only the owner to update buy and sell fees
	 */
	function updateStandardFees(
		uint256 _revenueFee,
		uint256 _treasuryFee
	) external onlyOwner {
		require(_revenueFee > 0, "XNOVA: Revenue fee should be greater than 0");
		require(
			_treasuryFee > 0,
			"XNOVA: Treasury fee should be greater than 0"
		);
		revenueFee = _revenueFee;
		treasuryFee = _treasuryFee;
		standardFee = _treasuryFee + _revenueFee;
		require(
			standardFee <= 200,
			"XNOVA: Standard fee should be less than or equal 20%"
		);
	}

	/**
	 * Function that allows only the owner to update transfer delay
	 */
	function updateTransferDelay(uint256 _transferDelay) external onlyOwner {
		trasferDelay = _transferDelay;
	}

	/**
	 * Function that allows only the owner to add or remove an address to whitelist
	 */
	function whitelist(address _address, bool _bool) external onlyOwner {
		whiteList[_address] = _bool;
		_isExcludedFromFee[_address] = _bool;
	}

	/**
	 * Function that allows only the owner to add or remove an address to blacklist
	 */
	function blacklist(address _address, bool _bool) external onlyOwner {
		blackList[_address] = _bool;
	}

	function setMultiToBlacklist(
		address[] memory _addresses,
		bool _bool
	) external onlyOwner {
		for (uint i = 0; i < _addresses.length; i++) {
			blackList[_addresses[i]] = _bool;
		}
	}

	/**
	 * Function that allows only the owner to change the number of accrued tokens to swap at
	 */
	function updateSwapTokensAtAmount(uint256 _amount) external onlyOwner {
		swapTokensAtAmount = _amount;
	}

	/**
	 * Function that allows only the owner to remove tokens from the contract
	 * Shield against attackers
	 */
	function removeBadToken(IERC20 Token) external onlyOwner {
		require(
			address(Token) != address(this),
			"XNOVA: You cannot remove this Token"
		);
		bool success = Token.transfer(owner(), Token.balanceOf(address(this)));
		require(success, "XNOVA: TOKEN TRANSFER FAILED");
	}

	/**
	 * Function that allows only the owner to remove XNOVA tokens, ETH from the contract
	 */
	function _removeDust() private {
		bool successErc20 = IERC20(address(this)).transfer(
			owner(),
			IERC20(address(this)).balanceOf(address(this))
		);
		require(successErc20, "XNOVA: TOKEN TRANSFER FAILED");
		(bool success, ) = payable(owner()).call{
			value: address(this).balance
		}("");
		require(success, "XNOVA: ETH TRANSFER FAILED");
	}

	/**
	 * Function that allows only the owner update the max number of tokens to sell per transaction
	 */
	function updateMaxSellAmount(uint256 _max) external onlyOwner {
		require(_max >= 25000 * 1e18 && _max <= 200000 * 1e18);
		maxSellTransactionAmount = _max;
	}

	/**
	 * Function that allows only the owner update the max number of tokens to buy per transaction
	 */
	function updateMaxBuyAmount(uint256 _max) external onlyOwner {
		require(_max >= 50000 * 1e18 && _max <= 300000 * 1e18);
		maxBuyTransactionAmount = _max;
	}

	function burn(uint256 amount) external {
		_burn(_msgSender(), amount);
	}

	/**
	 * Function: Overrides ERC20 Transfer
	 */
	function _transfer(
		address from,
		address to,
		uint256 amount
	) internal override {
		require(from != address(0), "ERC20: transfer from the zero address");
		require(to != address(0), "ERC20: transfer to the zero address");

		if (amount == 0) {
			super._transfer(from, to, 0);
			return;
		}

		bool noFee = _isExcludedFromFee[from] ||
			_isExcludedFromFee[to] ||
			disableFees ||
			to == address(uniswapV2Router);

		// Blacklisted can't transfer
		require(
			!(blackList[from] || blackList[to]),
			"Hacker Address Blacklisted"
		);

		if (
			!noFee &&
			(automatedMarketMakerPairs[from] ||
				automatedMarketMakerPairs[to]) &&
			!swapping
		) {
			require(tradingEnabled, "XNOVA: Trading Disabled");
			require(
				block.timestamp >= tradingEnabledTimestamp ||
					whiteList[from] ||
					whiteList[to],
				"XNOVA: Trading Still Not Enabled"
			);

			uint256 contractBalance = balanceOf(address(this));
			if (contractBalance >= swapTokensAtAmount) {
				if (!swapping && !automatedMarketMakerPairs[from]) {
					swapping = true;
					uint256 revenueAmount = contractBalance /
						(standardFee / revenueFee);
					uint256 treasuryAmount = contractBalance /
						(standardFee / treasuryFee);
					swapAndDistributeFee(revenueAmount, revenuewallet);
					swapAndDistributeFee(treasuryAmount, treasurywallet);
					swapping = false;
				}
			}

			// Get buy and sell fee amounts
			uint256 fees = (amount * (standardFee)) / (feeUnits);

			if (automatedMarketMakerPairs[from]) {
				require(
					amount <= maxBuyTransactionAmount,
					"XNOVA: Max Buy Amount Error"
				);
				if (transferDelayEnabled && !whiteList[to]) {
					require(
						(lastTransactionTime[to] == 0) ||
							(block.timestamp - lastTransactionTime[to] >=
								trasferDelay),
						"XNOVA: Next swap must be performed after the transfer delay"
					);
					lastTransactionTime[to] = block.timestamp;
				}
			}

			if (automatedMarketMakerPairs[to]) {
				require(
					amount <= maxSellTransactionAmount,
					"XNOVA: Max Sell Amount Error"
				);
				if (transferDelayEnabled && !whiteList[from]) {
					require(
						lastTransactionTime[from] == 0 ||
							block.timestamp - lastTransactionTime[from] >=
							trasferDelay,
						"XNOVA: Next swap must be performed after the transfer delay"
					);
					lastTransactionTime[from] = block.timestamp;
				}
			}

			super._transfer(from, address(this), fees);
			super._transfer(from, to, amount - fees);
		} else {
			super._transfer(from, to, amount);
		}
	}

	function swapAndDistributeFee(
		uint256 tokenAmount,
		address recipient
	) private {
		swapTokensForEth(tokenAmount, recipient);
		emit SwapAndDistributeFee(tokenAmount, recipient);
	}

	/**
	 * Function: to swap accrued fees to eth
	 */
	function swapTokensForEth(uint256 tokenAmount, address to) private {
		// generate the uniswap pair path of token -> weth
		address[] memory path = new address[](2);
		path[0] = address(this);
		path[1] = uniswapV2Router.WETH();

		_approve(address(this), address(uniswapV2Router), tokenAmount);

		// make the swap
		uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
			tokenAmount,
			0, // accept any amount of ETH
			path,
			to,
			block.timestamp
		);
	}

	function setAutomatedMarketMakerPair(
		address pair,
		bool value
	) external onlyOwner {
		require(
			pair != uniswapV2Pair,
			"XNOVA: The Uniswap pair cannot be removed from automatedMarketMakerPairs"
		);
		_setAutomatedMarketMakerPair(pair, value);
	}

	function _setAutomatedMarketMakerPair(address pair, bool value) private {
		require(
			automatedMarketMakerPairs[pair] != value,
			"XNOVA: Automated market maker pair is already set to that value"
		);
		automatedMarketMakerPairs[pair] = value;
		emit SetAutomatedMarketMakerPair(pair, value);
	}
}
