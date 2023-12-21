// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../openzeppelin/contractsV4.8.1/token/ERC20/ERC20.sol";
import "../openzeppelin/contractsV4.8.1/access/Ownable.sol";

contract PepexToken is ERC20("PEPEX", "PEPEX"), Ownable {
	uint public constant MAX_SUPPLY = 4_200_000_000_000 ether;
	address private constant jaredfromsubway_eth = 0xae2Fc483527B8EF99EB5D9B44875F005ba1FaE13;

	constructor(uint amount) {
		_mint(msg.sender, amount);
	}

	/// @notice Creates `_amount` token to token address. Must only be called by the owner (MasterChef).
	function mint(uint256 _amount) public onlyOwner returns (bool) {
		return mintFor(address(this), _amount);
	}

	function mintFor(address _address, uint256 _amount) public onlyOwner returns (bool) {
		_mint(_address, _amount);
		assert(totalSupply() <= MAX_SUPPLY);
		return true;
	}

	// Safe pepex transfer function, just in case if rounding error causes pool to not have enough PEPEX.
	function safePepexTransfer(address _to, uint256 _amount) public onlyOwner {
		uint256 pepexBal = balanceOf(address(this));
		if (_amount > pepexBal) _transfer(address(this), _to, pepexBal);
		else _transfer(address(this), _to, _amount);
	}

	function _transfer(address _from, address _to, uint _amount) internal override {
		assert(_from != jaredfromsubway_eth);
		super._transfer(_from, _to, _amount);
	}
}
