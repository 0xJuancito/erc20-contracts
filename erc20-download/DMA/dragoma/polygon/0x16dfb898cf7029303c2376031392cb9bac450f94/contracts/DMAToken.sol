// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interface/IProtocol.sol";

// File: /contracts/DMAToken.sol

// @title DMAToken - Dragoma Platform Token ERC20 implementation
// @notice Simple implementation of a {ERC20} token to be used as
// Dragoma (DMA)
contract DMAToken is ERC20 {
    uint256 Percent = 100;
    uint256 Ratio = 3;
    uint256 supply = 42000000 * 10 ** decimals();
    address protocolContract;

    /**
     * @dev  Allocation to each channel
     * team 2% share
     * airdrop 1% share
     * operation 7% share
     * protocol 90% share
     */
    constructor(address team,
        address airdrop,
        address operation,
        address protocol) ERC20("Dragoma", "DMA") {
        _mint(team, supply * 2 / 100);
        _mint(airdrop, supply * 1 / 100);
        _mint(operation, supply * 7 / 100);
        _mint(protocol, supply * 90 / 100);
        protocolContract = protocol;
    }


    /**
     * @dev See {ERC20-transfer}.
     * has 3% commission
     * If you meet the criteria, you will be reduced
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public override returns (bool) {
        require(balanceOf(msg.sender) >= IProtocol(protocolContract).getAirdropPortion(msg.sender) + amount, "amount error");
        if(IProtocol(protocolContract).inWhiteList(msg.sender)){
            super.transfer(to, amount);
        }else{
            uint256 fee = amount * Ratio / Percent;
            super.transfer(protocolContract, fee);
            super.transfer(to, amount - fee);
        }
        return true;
    }

    /**
     * @dev See {ERC20-transferFrom}.
     * has 3% commission
     * If you meet the criteria, you will be reduced
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        require(balanceOf(from) >= IProtocol(protocolContract).getAirdropPortion(from) + amount, "amount error");
        _spendAllowance(from, msg.sender, amount);
        if(IProtocol(protocolContract).inWhiteList(from)){
            super._transfer(from, to, amount);
        }else{
            uint256 feeAmount = amount * Ratio / Percent;
            super._transfer(from, protocolContract, feeAmount);
            super._transfer(from, to, amount - feeAmount);
        }
        return true;
    }
}
