// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract testnetToken is ERC20 {


	mapping(address => bool) public didMint;
	uint256 public mintAmount;

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 _mintAmount
    ) public ERC20(name, symbol) {
        _setupDecimals(decimals);
        mintAmount = _mintAmount;
        _mint(msg.sender, mintAmount);
    }

    function mint() public{
    	require(!didMint[msg.sender], "Sorry bruh...");
    	didMint[msg.sender] = true;
    	_mint(msg.sender, mintAmount);
    }

}