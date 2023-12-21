// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.7.0;

import "./Uniswap.sol";
import "./Ownable.sol";
import "./SafeMath.sol";
import "./Address.sol";

contract Swap is Ownable {	
	using SafeMath for uint256;
	using Address for address;
	
    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;
	
    bool public autoBuyBackEnabled = false;
	
	uint256 public minimumTokensBeforeSell = 0;
	uint256 public minimumBNBBeforeBuy = 0;
		
	event autoBuyBackChanged(
        bool enabled,
		uint256 minimumTokensBeforeSell,
		uint256 minimumBNBBeforeBuy 
    );
	
	event TeamAddressChanged(
        address addr,
        string addrType
    );

	event BuyBackAndBurned(
        uint256 bnb,
        address[] path
    );
    
    event SwapTokensForBNB(
        uint256 amountIn,
        address to,
        address[] path
    );
		
	constructor() internal {
		//IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0xD99D1c33F9fC3444f8101754aBC46c52416550D1);
		IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);

		uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());
		uniswapV2Router = _uniswapV2Router;
	}
		
	// Enable Auto BuyBack and Burn
	function enableAutoBuy(uint256 tokensBeforeSell, uint256 bnbBeforeBuy) external onlyOwner()  {
		autoBuyBackEnabled = true;
		minimumTokensBeforeSell = tokensBeforeSell;
		minimumBNBBeforeBuy = bnbBeforeBuy;
		
		emit autoBuyBackChanged(autoBuyBackEnabled, minimumTokensBeforeSell, minimumBNBBeforeBuy);
    }	

	// Disable Auto BuyBack and Burn
	function disableAutoBuy() external onlyOwner()  {
		autoBuyBackEnabled = false;
		minimumTokensBeforeSell = 0;
		minimumBNBBeforeBuy = 0;

		emit autoBuyBackChanged(autoBuyBackEnabled, minimumTokensBeforeSell, minimumBNBBeforeBuy);
    }
	
	// Swap Token to receive BNB
	function _swapTokensForBNB(uint256 token) internal {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
			token
			, 0
			, path
			, address(this)
			, block.timestamp
		);
        
        emit SwapTokensForBNB(token, address(this), path);
		
    }

	// Buy Back Token and burn them 
    function _buyBackAndBurnToken(uint256 bnb) internal {
		address deadAddress = 0x000000000000000000000000000000000000dEaD;

        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = address(this);

        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: bnb}(
			0
			, path
			, deadAddress // Tokens are burned
			, block.timestamp.add(300)
		);
        
        emit BuyBackAndBurned(bnb, path);
    }
}