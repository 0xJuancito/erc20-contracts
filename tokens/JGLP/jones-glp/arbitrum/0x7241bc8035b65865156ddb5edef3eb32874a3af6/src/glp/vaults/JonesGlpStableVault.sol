// SPDX-License-Identifier: UNLICENSED

// Copyright (c) 2023 Jones DAO - All rights reserved
// Jones DAO: https://www.jonesdao.io/

pragma solidity ^0.8.10;

import {JonesBaseGlpVault} from "./JonesBaseGlpVault.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IAggregatorV3} from "../../interfaces/IAggregatorV3.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract JonesGlpStableVault is JonesBaseGlpVault {
    uint256 public constant BASIS_POINTS = 1e12;

    constructor()
        JonesBaseGlpVault(
            IAggregatorV3(0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3),
            IERC20Metadata(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8),
            "USDC Vault Receipt Token",
            "UVRT"
        )
    {}

    // ============================= Public functions ================================ //

    function deposit(uint256 _assets, address _receiver)
        public
        override(JonesBaseGlpVault)
        whenNotPaused
        returns (uint256)
    {
        _validate();
        return super.deposit(_assets, _receiver);
    }

    /**
     * @dev See {openzeppelin-IERC4626-_burn}.
     */
    function burn(address _user, uint256 _amount) public onlyOperator {
        _validate();
        _burn(_user, _amount);
    }

    /**
     * @notice Return total asset deposited
     * @return Amount of asset deposited
     */
    function totalAssets() public view override returns (uint256) {
        return super.totalAssets() + strategy.stableDebt();
    }

    // ============================= Governor functions ================================ //

    /**
     * @notice Emergency withdraw USDC in this contract
     * @param _to address to send the funds
     */
    function emergencyWithdraw(address _to) external onlyGovernor {
        IERC20 underlyingAsset = IERC20(super.asset());

        uint256 balance = underlyingAsset.balanceOf(address(this));

        if (balance == 0) {
            return;
        }

        underlyingAsset.transfer(_to, balance);
    }

    // ============================= Private functions ================================ //

    function _validate() private {
        uint256 shares = totalSupply() / BASIS_POINTS;
        uint256 assets = totalAssets();
        address stable = asset();

        if (assets > shares) {
            uint256 ratioExcess = assets - shares;
            IERC20(stable).transfer(receiver, ratioExcess);
        }
    }
}
