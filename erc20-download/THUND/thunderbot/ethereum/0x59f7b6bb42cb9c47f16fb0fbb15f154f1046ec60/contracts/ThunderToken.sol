/**
    ThunderBot
    The Power of AI in your Trading Bot

    Website : https://thunderbot.app
    Twitter : https://twitter.com/ThunderBotApp
    Telegram : https://t.me/thunderbotapp_bot
**/

// SPDX-License-Identifier: MIT

pragma solidity >=0.8.8;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

import "./tokenFees/FeeRegistry.sol";

contract ThunderBotToken is ERC20Capped, Ownable {
    FeeRegistry public feeRegistry;

    mapping(address => bool) public uniswapV2Pairs;
    mapping(address => bool) public whitelistedAddresses;

    uint256 public tokenBuySellFees = 500;
    uint256 public tokenRevShareFees = 40;

    address public teamWallet;
    address public revShareWallet;

    /**
     * @dev Initializes the contract with a fee registry address.
     * @param _feeRegistry Fee registry address
     */
    constructor(
        address _feeRegistry
    ) ERC20("ThunderBot", "THUND") ERC20Capped(1000000 * 10 ** decimals()) {
        _mint(msg.sender, 1000000 * 10 ** decimals());
        feeRegistry = FeeRegistry(_feeRegistry);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    /**
     * @dev Set the token buy/sell fees. Can only be called by the owner.
     * @param _tokenBuySellFees Token buy/sell fees amount
     */
    function setTokenBuySellFees(uint256 _tokenBuySellFees) public onlyOwner {
        require(_tokenBuySellFees <= 10000, "Invalid fee percentage");
        tokenBuySellFees = _tokenBuySellFees;
    }

    /**
     * @dev Set the token revenue share fees. Can only be called by the owner.
     * @param _tokenRevShareFees Token revenue share fees amount
     */
    function setRevShareFees(uint256 _tokenRevShareFees) public onlyOwner {
        require(_tokenRevShareFees <= 100, "Invalid fee percentage");
        tokenRevShareFees = _tokenRevShareFees;
    }

    /**
     * @dev Sets the team wallet address. Can only be called by the owner.
     * @param _address Wallet address
     */
    function setTeamWallet(address _address) public onlyOwner {
        teamWallet = _address;
    }

    /**
     * @dev Sets the revenue share wallet address. Can only be called by the owner.
     * @param _address Wallet address
     */
    function setRevShareWallet(address _address) public onlyOwner {
        revShareWallet = _address;
    }

    /**
     * @dev Calculates the fee amount based on the fee percentage.
     * @param amount Amount of tokens to swap
     */
    function calculateFee(uint256 amount) public view returns (uint256) {
        return (amount * tokenBuySellFees) / 10000;
    }

    /**
     * @dev Overrides the transfer function to add fees logic.
     * @param from Address to transfer from
     * @param to Address to transfer to
     * @param amount Amount of tokens to transfer
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fees = 0;
        bool isWhitelisted = whitelistedAddresses[from] ||
            whitelistedAddresses[to];

        if (!isWhitelisted && feeRegistry.shouldApplyFees(from, to)) {
            fees = calculateFee(amount);
        }

        if (fees > 0) {
            uint256 teamWalletAmount = (fees * (100 - tokenRevShareFees)) / 100;
            uint256 revShareWalletAmount = (fees * tokenRevShareFees) / 100;

            super._transfer(from, teamWallet, teamWalletAmount);
            super._transfer(from, revShareWallet, revShareWalletAmount);
        }

        super._transfer(from, to, amount - fees);
    }

    /**
     * @dev The whitelist is used to add liquidity to the Uniswap router.
     * @param addr Address to whitelist
     */
    function whitelistAddress(address addr) public onlyOwner {
        whitelistedAddresses[addr] = true;
    }

    function removeFromWhitelist(address addr) public onlyOwner {
        whitelistedAddresses[addr] = false;
    }
}
