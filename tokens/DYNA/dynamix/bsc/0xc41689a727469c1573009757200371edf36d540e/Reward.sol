// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.7.0;

import "./Holder.sol";
import "./Ownable.sol";
import "./SafeMath.sol";

contract Reward is Ownable, Holder {
	using SafeMath for uint256;
	
	struct Balance {
        uint256 reward; 
        uint256 token;  
        bool excludedFromReward;    
		uint timestamp;
    }
	
    mapping (address => Balance) internal _balances;

    uint256 internal _tokenSupply;
    uint256 internal _rewardSupply;
	
    address[] private _excludedFromRewardAddr;
		
	constructor(uint256 totalSupply) public {
		require(totalSupply <= 1000000000000000000000000, "totalSupply is too high");
		
		_tokenSupply = totalSupply;
		_rewardSupply = (~uint256(0) - (~uint256(0) % _tokenSupply));
		
		_balances[_msgSender()].reward = _rewardSupply;
		_balances[_msgSender()].timestamp = block.timestamp;		
	}
		
	// Transfer Token 
	function _transfer(address sender, address recipient, uint256 tokenAmount, uint256 fee) internal returns (uint256) {		
		uint256 rate = _getRate();		
		recipientTransfert(_balances[recipient].reward.div(rate));
		
		// Compute Fees
		uint256 tokenFee = tokenAmount.mul(fee).div(100);
        uint256 tokenToTransfertAmount = tokenAmount.sub(tokenFee, "tokenAmount sub tokenFee");
		
		// Convert Token Amount to Transfert to Reward Amount
		uint256 rewardAmount = tokenAmount.mul(rate);
        uint256 rewardFee = tokenFee.mul(rate);
        uint256 rewardToTransferAmount = rewardAmount.sub(rewardFee, "rewardAmount sub rewardFee");

		// Transfert Reward
		_balances[sender].reward = _balances[sender].reward.sub(rewardAmount, "reward sub rewardAmount");
        _balances[recipient].reward = _balances[recipient].reward.add(rewardToTransferAmount);       
		
		// Transfert Exclude
		if(_balances[sender].excludedFromReward)
			_balances[sender].token = _balances[sender].token.sub(tokenAmount, "token sub tokenAmount");
		
		if(_balances[recipient].excludedFromReward)
			_balances[recipient].token = _balances[recipient].token.add(tokenToTransfertAmount);
		
		// Update Reward Supply
		_rewardSupply = _rewardSupply.sub(rewardFee, "_rewardSupply sub rewardFee");
		
		senderTransfert(_balances[sender].reward.div(rate));
		
		return tokenToTransfertAmount;
	}

	// Get Total Token Supply and Rewards 
	function _getTotalSupplyAndTotalReward() private view returns(uint256, uint256) {
        uint256 rewardTotal = _rewardSupply;
        uint256 tokenTotal = _tokenSupply;      
		
        for (uint256 i = 0; i < _excludedFromRewardAddr.length; i++) {
			uint256 reward = _balances[_excludedFromRewardAddr[i]].reward;
			uint256 token = _balances[_excludedFromRewardAddr[i]].token;
			
            if (reward > rewardTotal || token > tokenTotal) 
				return (_rewardSupply, _tokenSupply);
			
            rewardTotal = rewardTotal.sub(reward);
            tokenTotal = tokenTotal.sub(token);
        }
		
        if (rewardTotal < _rewardSupply.div(_tokenSupply)) 
			return (_rewardSupply, _tokenSupply);
		
        return (rewardTotal, tokenTotal);
    }
	
	// Convert Reward to Token
	function _rewardToToken(uint256 reward) internal view returns(uint256) {
        require(reward <= _rewardSupply, "Reward Amount must be less than Reward Supply");
		
        uint256 rate = _getRate();
        return reward.div(rate);
    }
	
	// Get Rate between Reward Supply and Token Supply
	function _getRate() private view returns(uint256) {
        (uint256 rewardSupply, uint256 tokenSupply) = _getTotalSupplyAndTotalReward();
		
        return rewardSupply.div(tokenSupply);
    }
	
	// Exclude an account from rewards
	function excludeAccountFromRewards(address account) external onlyOwner()  {
        require(!_balances[account].excludedFromReward, "Account is not excluded");
		
        if(_balances[account].reward > 0) 
            _balances[account].token = _rewardToToken(_balances[account].reward); 
        
        _balances[account].excludedFromReward = true;
		
        _excludedFromRewardAddr.push(account);
    }

	// Include an account in rewards
    function includeAccountInRewards(address account) external onlyOwner() {
        require(_balances[account].excludedFromReward, "Account is excluded");
		
        for (uint256 i = 0; i < _excludedFromRewardAddr.length; i++) {
            if (_excludedFromRewardAddr[i] == account) {
                _excludedFromRewardAddr[i] = _excludedFromRewardAddr[_excludedFromRewardAddr.length - 1];
				_excludedFromRewardAddr.pop();

                _balances[account].token = 0;
				_balances[account].excludedFromReward = false;
				
                break;
            }
        }
    }
		
	// Account Balance Informations
	function accountBalance(address account) external view returns(uint256, uint256, bool, uint) {
        return (_balances[account].reward
				, _balances[account].token
				, _balances[account].excludedFromReward
				, _balances[account].timestamp
				);	
    }
}