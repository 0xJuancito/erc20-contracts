// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract DummyOP is ERC20 {

	mapping(address => bool) public didMint;

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals
    ) public ERC20(name, symbol) {
        _setupDecimals(decimals);
        _mint(msg.sender, 30000*10**18);
    }

    function mint() public{
    	require(!didMint[msg.sender], "Once per account...");
    	didMint[msg.sender] = true;
    	_mint(msg.sender, 20000*10**18);
    }

}