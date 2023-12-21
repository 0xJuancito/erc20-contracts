// SPDX-License-Identifier: UNLICENSED

// Copyright (c) 2023 Jones DAO - All rights reserved
// Jones DAO: https://www.jonesdao.io/

pragma solidity ^0.8.10;

import {ERC4626} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {JonesGovernableVault} from "./JonesGovernableVault.sol";
import {IAggregatorV3} from "../interfaces/IAggregatorV3.sol";
import {IJonesUsdVault} from "../interfaces/IJonesUsdVault.sol";

abstract contract JonesUsdVault is JonesGovernableVault, ERC4626, IJonesUsdVault {
    IAggregatorV3 public priceOracle;

    constructor(IAggregatorV3 _priceOracle) {
        priceOracle = _priceOracle;
    }

    function setPriceAggregator(IAggregatorV3 _newPriceOracle) external onlyGovernor {
        emit PriceOracleUpdated(address(priceOracle), address(_newPriceOracle));

        priceOracle = _newPriceOracle;
    }

    function tvl() external view returns (uint256) {
        return _toUsdValue(totalAssets());
    }

    function _toUsdValue(uint256 _value) internal view returns (uint256) {
        IAggregatorV3 oracle = priceOracle;

        (, int256 currentPrice,,,) = oracle.latestRoundData();

        uint8 totalDecimals = IERC20Metadata(asset()).decimals() + oracle.decimals();
        uint8 targetDecimals = 18;

        return totalDecimals > targetDecimals
            ? (_value * uint256(currentPrice)) / 10 ** (totalDecimals - targetDecimals)
            : (_value * uint256(currentPrice)) * 10 ** (targetDecimals - totalDecimals);
    }

    event PriceOracleUpdated(address _oldPriceOracle, address _newPriceOracle);
}
