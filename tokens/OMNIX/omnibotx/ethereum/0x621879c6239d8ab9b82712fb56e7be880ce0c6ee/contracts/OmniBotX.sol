// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@layerzerolabs/solidity-examples/contracts/token/oft/extension/BasedOFT.sol";

contract OmniBotX is BasedOFT, ERC20Permit {
	struct Taxes {
		uint from; // buy + lp removed
		uint to; // sell + lp added
	}

	mapping(address => bool) public isExcludedFromFee;
	mapping(address => Taxes) public taxes;
	address public taxReceiver;

	uint internal constant MAX_TAX = 9000;
	uint internal constant PRECISION = 10000;

	event SetExcludedFromFee(address who, bool isExcludedFromFee);
	event SetTaxes(address who, uint from, uint to);
	event SetTaxReceiver(address who);

	constructor(
		string memory _name, 
		string memory _symbol,
		uint _totalSupply,
		address _multisig,
		address _lzEndpoint
	) 
		BasedOFT(_name, _symbol, _lzEndpoint) 
		ERC20Permit(_name)
	{
		_mint(_multisig, _totalSupply);

		isExcludedFromFee[_msgSender()] = true;
		emit SetExcludedFromFee(_msgSender(), true);

		isExcludedFromFee[_multisig] = true;
		emit SetExcludedFromFee(_multisig, true);

		taxReceiver = _multisig;
		emit SetTaxReceiver(_multisig);
	}

	function setIsExcludedFromFee(address _who, bool _value) external onlyOwner {
		isExcludedFromFee[_who] = _value;
		emit SetExcludedFromFee(_who, _value);
	}

	function setTaxes(address _who, uint _from, uint _to) external onlyOwner {
		require(Address.isContract(_who), "eoa protection");
		require(_from <= MAX_TAX && _to <= MAX_TAX, "lower than 90%");
		taxes[_who] = Taxes(_from, _to);
		emit SetTaxes(_who, _from, _to);
	}
	
	function setTaxReceiver(address _who) external onlyOwner {
		assert(_who != address(0));
		taxReceiver = _who;
		emit SetTaxReceiver(_who);
	}

	function _transfer(address from, address to, uint256 amount) internal override {
		uint finalAmount = amount;

		if (!isExcludedFromFee[from] && !isExcludedFromFee[to]) {
			uint taxFrom = taxes[from].from;
			if (taxFrom > 0) finalAmount -= amount * taxFrom / PRECISION;

			uint taxTo = taxes[to].to;
			if (taxTo > 0) finalAmount -= amount * taxTo / PRECISION;
		}

		super._transfer(from, to, finalAmount);
		if (finalAmount != amount) super._transfer(from, taxReceiver, amount - finalAmount);
	}
}
