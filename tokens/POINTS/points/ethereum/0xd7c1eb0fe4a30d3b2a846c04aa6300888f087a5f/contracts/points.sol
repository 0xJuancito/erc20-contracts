// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract POINTS is ERC20, Ownable {
    uint256 public MAX_SUPPLY;
    uint256 public MINT_INCREMENT;
    uint256 public constant PRICE_PER_HUNDRED_TOKENS = 0.0001 ether;

    constructor(address initialOwner)
        ERC20("POINTS", "POINTS")
        Ownable(initialOwner)
    {
        MAX_SUPPLY = 1000000000 * 10 ** decimals();
        MINT_INCREMENT = 100 * 10 ** decimals();
        _mint(initialOwner, 1000000 * 10 ** decimals());
    }

    /**
     * @notice Mints new tokens in increments of 100, with a cost of 0.0001 ETH per 100 tokens.
     * @param numberOfHundreds The number of hundreds of tokens to mint.
     */
    function mint(uint256 numberOfHundreds) public payable {
        uint256 tokensToMint = numberOfHundreds * MINT_INCREMENT;
        uint256 requiredPayment = numberOfHundreds * PRICE_PER_HUNDRED_TOKENS;

        require(msg.value >= requiredPayment, "Insufficient ETH sent");
        require(totalSupply() + tokensToMint <= MAX_SUPPLY, "Max supply exceeded");

        _mint(msg.sender, tokensToMint);
        
        if (msg.value > requiredPayment) {
            payable(msg.sender).transfer(msg.value - requiredPayment);
        }
    }

    /**
     * @notice Allows the contract owner to airdrop tokens to a specified address.
     * @param to The address to receive the airdropped tokens.
     * @param amount The amount of tokens to airdrop.
     */
    function airdrop(address to, uint256 amount) public onlyOwner {
        uint256 amountWithDecimals = amount * 10 ** decimals();
        require(totalSupply() + amountWithDecimals <= MAX_SUPPLY, "Max supply exceeded");
        _mint(to, amountWithDecimals);
    }

    function withdraw() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
