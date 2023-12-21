pragma solidity ^0.8.8;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC2222/extensions/FDT_ERC20Extension.sol";
/**
 * @title EDT_RewardToken
 * @author Niccolo' Petti
 * @dev AN ERC2222 token only transferrable by the owner address, with the option of 
 * excluding an address from Rewards, redistributing its withdrawable funds to the other users
*/
contract EDT_RewardToken is FDT_ERC20Extension, Ownable {

  mapping(address => bool) public isExcludedFromRewards;

  event ExcludedFromRewards(address user, bool toBeExcluded);

    constructor(
        string memory name,
        string memory symbol,
        IERC20 _fundsToken
    ) FDT_ERC20Extension(name, symbol,_fundsToken) {

    }
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 value
    ) internal override onlyOwner{
    }
    
     function setBalance(address account, uint256 newBalance) external onlyOwner {
    	if(isExcludedFromRewards[account]) {
    		return;
    	}
        uint256 currentBalance = balanceOf(account);

        if(newBalance > currentBalance) {
          uint256 mintAmount = newBalance-currentBalance;
          _mint(account, mintAmount);
        } else if(newBalance < currentBalance) {
          uint256 burnAmount = currentBalance-newBalance;
          _burn(account, burnAmount);
        }
    }

    function setIsExcludedFromRewards(address account, bool toBeExcluded) external onlyOwner {
      require(isExcludedFromRewards[account]!=toBeExcluded, "account already set to that status");
      isExcludedFromRewards[account]=toBeExcluded;
      emit ExcludedFromRewards(account,toBeExcluded);
      if(toBeExcluded)
      { 
        _burn(account,balanceOf(account));
        uint256 _withdrawableFunds = withdrawableFundsOf(account);
        if(_withdrawableFunds!=0)
        { //we redistribute the claimable funds of the excluded account to all the other holders
        withdrawnFunds[account] += _withdrawableFunds; 
        _distributeFunds(_withdrawableFunds);
        }
      }
      else
      {
      _mint(account, IERC20(owner()).balanceOf(account));
      }

    }


}
