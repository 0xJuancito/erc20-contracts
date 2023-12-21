// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Rekt is Context, ERC20 {

	constructor(uint256 _supply) ERC20("REKT", "REKT") {
		_mint(msg.sender, _supply);
	}

	function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}
