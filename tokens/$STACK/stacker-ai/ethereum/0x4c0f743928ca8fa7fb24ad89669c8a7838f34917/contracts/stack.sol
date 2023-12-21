// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract STACK is ERC20, ERC20Burnable, ERC20Permit, Ownable {
    address public uniswapV2Pair;
    bool public limited;
    uint256 public taxRate = 3;
    address public taxWallet = 0x8fF6195B681418E738eE2fACCF2Aa862529F104e;
    address[] private WL_PRESALE = [
        0xF8303F2DEAb54F99e76f6F2B4c0FF644824D2853,
        0xB1E7585FF8712C9E2736FAB60C4DAd5e8De9e763,
        0x3A3E2F5D937cf0bdc4FB0A9bbbB8cD6FA09f3031,
        0x57fB9c5Fa2D369f69d8664BE1077b9C273A94401,
        0xF4B44545D056A20254a64BC3e91f63bC023EF9EC,
        0xadEC621BCa1c2E76DD18f1041f15099aF9Aef75B,
        0x8686BF551d92dE8F2d9568e329c29a39fa3FdE29,
        0xd9127B19B94FFcdd3cF7A6F3aEA5BD51a15bf432,
        0xD0dDfC1d847B8D4cBF91972e73018F138cA86bA3,
        0x58556648C4d7987Ed7Ab3DfD3c2190a40baaD6C2,
        0x1b2b1Ad98BE96ad5CB487A67d4e74168296A7ace,
        0x4Af50f8d848791B44fB8D27B8Dc7bca96e18A409,
        0x063845926b82481376495350066B157b28dE6721,
        0x6Efd42BD1F8fE17197209243515500aF012416D9,
        0x55902F686DBE785faF66c66F782Cf86566B166A3,
        0x4c1A860fC9d39a98e480789A3d1b8359DFe1A6aB,
        0xD1B619adb6Ce89e5dE561013d2cA2be5fdA97fc7,
        0x5f04dC8D2B3003f808C900C828Fb9b1332478087,
        0x72533B6Ac6e0b5000726b9Eae708f964D51f2A75,
        0x1EFE00F53AD42a1A07D74929284d4a0275e5e7D5,
        0xc3fEcA86bA736645192c13500386DFd1A393b771,        
        0xFDD8F6Db6A6B6Eb42E677359989608215376EfC6,
        0x8762f519E72f4d8834A72Eba4927b672336Eb503,
        0x82f19814b9445c3aFA3BEbC4e6cc9DaaF4b7Df90,
        0x97458B1439b3613070631160A36aE4C073b68631,
        0x970B80F1e7EFD59913cc23fCDF4E6bAC22E60F52,
        0xE8D5Eea64FB1dC8fFfa2cC0A3723ed9A26162d4B,        
        0x20278e607cB00683Dc9C0f355B7Ec1BF9cF2bB4C,
        0x1dDbeb90A12609A827496BF5a03a65e93f3441F0,
        0x9f74E2a138FE20692AA7e6540dd27F59013D8ffa,
        0x2559F01CC997231B2fef2249e5CedA64886DF35f,
        0x81ae9c89ACCeBBcc33A5ba9E044d6ac2bFe0B348,
        0xf53359B4881f127125f0C3d2b1433fB4C59f9839,
        0xDdE149b351D2731548f7bc994dF3717e197147e3,
        0x61D0C6c7eE4B3F4E9EB96097De075C619F2720e5,
        0xbBA646c5f4eb96e379883Df4E1492fF47f6e6232,
        0xb87B623bB76b1A42c955dddfC27D98d9cfDD5A08,
        0xfb35d0F84Cb01b103bE7729f31FEc24ae388BFad
    ];

    constructor()
        ERC20("$STACK", "$STACK")
        ERC20Permit("$STACK")
        Ownable(msg.sender)
    {
        _mint(msg.sender, 100000000 * 10**decimals());
    }

    function setRule(address _uniswapV2Pair) external onlyOwner {
        limited = true;
        uniswapV2Pair = _uniswapV2Pair;
    }

    function activatePublicSale() external onlyOwner {
        limited = false;
    }

    function updateTaxWallet(address _taxWallet) external onlyOwner {
        taxWallet = _taxWallet;
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override {
        if (uniswapV2Pair == address(0) && from != address(0)) {
            require(from == owner() || to == owner(), "trading is not started");
        }
        if (
            limited &&
            from == uniswapV2Pair &&
            (to != owner() && from != owner()) &&
            (to != taxWallet && from != taxWallet)
        ) {
            require(
                super.balanceOf(to) + value <= (totalSupply() * 15) / 1000,
                "Forbid, You Can't hold more than 1.5% of the supply"
            );
            // check to is WL
            require(isWhiteListed(to), "Your Address Is Not Whitelisted");
        }
        if (
            uniswapV2Pair != address(0) &&
            taxWallet != address(0) &&
            (from == uniswapV2Pair || to == uniswapV2Pair) &&
            (from != owner() && to != owner()) &&
            (from != taxWallet && to != taxWallet)
        ) {
            uint256 taxAmount = (value * taxRate) / 100;
            uint256 taxedAmount = value - taxAmount;

            super._update(from, taxWallet, taxAmount);

            super._update(from, to, taxedAmount);
        } else {
            super._update(from, to, value);
        }
    }

    function isWhiteListed(address _address) public view returns (bool) {
        for (uint256 i = 0; i < WL_PRESALE.length; i++) {
            if (WL_PRESALE[i] == _address) {
                return true;
            }
        }
        return false;
    }
}
