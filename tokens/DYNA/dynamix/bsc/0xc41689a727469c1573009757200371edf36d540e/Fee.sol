// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.7.0;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./Address.sol";

contract Fee is Ownable {		
	using SafeMath for uint256;
	using Address for address;

    mapping (address => bool) internal _pair;
    mapping (address => bool) internal _excludedFromFee;

	uint256 public sellFee = 0;
	uint256 public buyFee = 0;

	address public teamAddress = 0x34A1a24BB6C8a692e6F5f7650C89bd88cB51A28d;
		
	event PreSaleStarted(
        uint256 sellFee,
        uint256 buyFee
    );
	
	event PreSaleCompleted(
        uint256 sellFee,
        uint256 buyFee
    );
	
	event TeamAddressChanged(
        address addr
    );
	
	constructor() internal {
		address deadAddress = 0x000000000000000000000000000000000000dEaD;
		
		_excludedFromFee[_msgSender()] = true;
		_excludedFromFee[address(this)] = true;
		_excludedFromFee[teamAddress] = true;
		_excludedFromFee[deadAddress] = true;
	}
	
	// Manage Excluded Addr
	function setExcludedFromFee(address account, bool excluded) external onlyOwner()  {
        _excludedFromFee[account] = excluded;
    }	
	
	// Manage Pair Address
	function setPair(address account, bool isPair) external onlyOwner()  {
        _pair[account] = isPair;
    }	
	
	// Is Tx Buy (in another words from pair)
	function _isBuy(address sender) internal view returns(bool) {
        return _pair[sender];
    }
	
	// Is Tx Sell (in another words to pair)
	function _isSell(address recipient) internal view returns(bool) {
        return _pair[recipient];
    }
	
	// Get Buy Fee (depending holders)
	function _getBuyFee(uint256 amount, uint256 holders) internal view returns(uint256, uint256, uint256) {
		if(buyFee == 0) 
			return (0, 0, amount);
		
		uint256 rewardFee = _getRewardFee(holders);
		uint256 teamFee = buyFee - rewardFee;
		
		uint256 tokenToTeam = amount.mul(teamFee).div(100);
        uint256 tokenToOwner = amount.sub(tokenToTeam);

		return (rewardFee, tokenToTeam, tokenToOwner);
    }
	
	// Get Reward Fee (depending holders)
	function _getRewardFee(uint256 holders) internal pure returns(uint256) {
        if(holders <= 10000)
			return 2;
        if(holders <= 20000)
			return 3;
        if(holders <= 50000)
			return 4;
		if(holders <= 100000)
			return 6;
		
		return 8;
    }
	
	// Get Sell Fee (depending hold time)
	function _getSellFee(uint256 amount, uint timestamp) internal view returns(uint256, uint256, uint256) {
		if(sellFee == 0) 
			return (0, 0, amount);
		
		uint256 fee = _getHoldFee(timestamp);
		
		uint256 tokenToTeam = amount.mul(fee).div(100);
        uint256 tokenToOwner = amount.sub(tokenToTeam);
		
        uint256 tokenToBuyBack = tokenToTeam.mul(35).div(100);
		tokenToTeam = tokenToTeam.sub(tokenToBuyBack);
		
		return (tokenToBuyBack, tokenToTeam, tokenToOwner);
    }
	
	// Get Hold Fee (depending hold time)
	function _getHoldFee(uint timestamp) internal view returns(uint256) {
        uint diff = block.timestamp - timestamp;

		if(diff <= 604800) // 1 Week: 3600 * 24 * 7
			return sellFee;
		if(diff <= 2592000) // 1 Month: 3600 * 24 * 30
			return 14;
		if(diff <= 15552000) // 6 Months: 3600 * 24 * 30 * 6
			return 8;
		
		return 5; // > 6 Months
    }
		
	// Set Team Address
	function setTeamAddress(address addr) external onlyOwner() {
        teamAddress = addr;
		_excludedFromFee[teamAddress] = true;

		TeamAddressChanged(addr);
    }
	
	// Disable Fee
	function disableFee() external onlyOwner()  {
		sellFee = 0;
		buyFee = 0;
    }
	
	// Enable Fee
	function enableFee() external onlyOwner()  {
		sellFee = 17;
		buyFee = 12;
    }
}