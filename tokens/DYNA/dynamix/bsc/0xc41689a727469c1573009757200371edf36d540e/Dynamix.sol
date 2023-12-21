// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.7.0;

/****************************************************************************************
 ██████████   █████ █████ ██████   █████   █████████   ██████   ██████ █████ █████ █████
░░███░░░░███ ░░███ ░░███ ░░██████ ░░███   ███░░░░░███ ░░██████ ██████ ░░███ ░░███ ░░███ 
 ░███   ░░███ ░░███ ███   ░███░███ ░███  ░███    ░███  ░███░█████░███  ░███  ░░███ ███  
 ░███    ░███  ░░█████    ░███░░███░███  ░███████████  ░███░░███ ░███  ░███   ░░█████   
 ░███    ░███   ░░███     ░███ ░░██████  ░███░░░░░███  ░███ ░░░  ░███  ░███    ███░███  
 ░███    ███     ░███     ░███  ░░█████  ░███    ░███  ░███      ░███  ░███   ███ ░░███ 
 ██████████      █████    █████  ░░█████ █████   █████ █████     █████ █████ █████ █████
░░░░░░░░░░      ░░░░░    ░░░░░    ░░░░░ ░░░░░   ░░░░░ ░░░░░     ░░░░░ ░░░░░ ░░░░░ ░░░░░ 
                                                                                        
> More information on https://dynamix.finance/

*****************************************************************************************/
                                                                                        
import "./IERC20.sol";
import "./Reward.sol";
import "./Fee.sol";
import "./Address.sol";
import "./Swap.sol";

contract Dynamix is Reward, IERC20, Fee, Swap {
	using SafeMath for uint256;
	using Address for address;
	
	mapping (address => mapping (address => uint256)) private _allowances;
	
	string public name = 'Dynamix';
    string public symbol = 'DYNA';
    uint8 public decimals = 9;
	
	constructor(uint256 totalSupply) 
		public Reward(totalSupply) {
			emit Transfer(address(0), _msgSender(), totalSupply);
	}
	
	function totalSupply() public view override returns (uint256) {
        return _tokenSupply;
    }
	
	function balanceOf(address account) public view override returns (uint256)  {
        if (_balances[account].excludedFromReward) 
			return _balances[account].token;
		
        return _rewardToToken(_balances[account].reward);
    }
	
	function transfer(address recipient, uint256 amount) public override returns (bool) {
		 _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }
	
	function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
	
	// Internal Transfer, and fee management
	function _transfer(address sender, address recipient, uint256 amount) private {
		uint256 rewardFee = 0;
		bool excludedFromFee = _excludedFromFee[sender] || _excludedFromFee[recipient];
		
		if(!excludedFromFee) {
			if(_isBuy(sender)) {
				(uint256 rFee, uint256 tokenToTeam, uint256 tokenToOwner) = _getBuyFee(amount, holders);
				_transfer(sender, teamAddress, tokenToTeam, 0);
				
				// Init timestamp for token hold
				_balances[recipient].timestamp = block.timestamp;
				
				rewardFee = rFee;
				amount = tokenToOwner;
				
				emit Transfer(sender, teamAddress, tokenToTeam);
			}
			
			if(_isSell(recipient)) {
				(uint256 tokenToBuyBack, uint256 tokenToTeam, uint256 tokenToOwner) = _getSellFee(amount, _balances[sender].timestamp);
				_transfer(sender, teamAddress, tokenToTeam, 0);
				_transfer(sender, address(this), tokenToBuyBack, 0);
				
				amount = tokenToOwner;
				
				emit Transfer(sender, teamAddress, tokenToTeam);
				emit Transfer(sender, address(this), tokenToBuyBack);
				
				if(!inSellOrBuy)
					_sellAndBuy();
			}
		}
		
        amount = _transfer(sender, recipient, amount, rewardFee);
		
		emit Transfer(sender, recipient, amount);
	}
	
    receive() external payable {}

	bool inSellOrBuy;

	modifier lockTheSwap {
        inSellOrBuy = true;
        _;
        inSellOrBuy = false;
    }
		
	// Sell and BuyBack
	function _sellAndBuy() private lockTheSwap {
		if(autoBuyBackEnabled){
			
			// Sell Tokens for BuyBack
			uint256 contractToken = balanceOf(address(this));
			if (contractToken >= minimumTokensBeforeSell) {
				_approve(address(this), address(uniswapV2Router), contractToken);
				_swapTokensForBNB(contractToken); 	
			}
			
			// Buy Tokens
			uint256 contractBnb = address(this).balance;
			
			if (contractBnb >= minimumBNBBeforeBuy) 
				_approve(address(this), address(uniswapV2Router), contractBnb);
				_buyBackAndBurnToken(contractBnb); // BuyBack and Burn
		}
	}
	
	// Before PreSale, no fees
	function beforePreSale() external onlyOwner()  {
		sellFee = 0;
		buyFee = 0;
		autoBuyBackEnabled = false;
		minimumTokensBeforeSell = 0;
		minimumBNBBeforeBuy = 0;

		emit PreSaleStarted(sellFee, buyFee);
    }
	
	// After PreSale, initialization fees
	function afterPreSale(address account) external onlyOwner()  {
		sellFee = 17;
		buyFee = 12;
		_pair[account] = true;
		autoBuyBackEnabled = true;
		minimumTokensBeforeSell = 1000 * 10**9 * 10**9;
		minimumBNBBeforeBuy = 1 * 10**16;

		emit PreSaleCompleted(sellFee, buyFee);
    }
}