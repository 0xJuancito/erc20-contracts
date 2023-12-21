//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract BabiToken is ERC20Burnable {
    constructor() ERC20("Babylons Governance Token", "BABI") {
		_mint(_msgSender(), 195000000*(10**decimals()));
	}
}