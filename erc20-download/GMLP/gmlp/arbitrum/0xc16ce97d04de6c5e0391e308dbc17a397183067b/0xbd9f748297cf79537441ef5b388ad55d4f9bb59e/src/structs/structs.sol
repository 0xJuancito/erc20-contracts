// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@vault/IVault.sol";

enum PairType {
    USDC,
    WETH
}

struct CoinPriceUSD {
    address coin;
    uint256 price;
}

struct CoinWeight {
    address coin;
    uint256 weight;
}

struct CoinValue {
    address coin;
    uint256 value;
}

struct CoinWeightsParams {
    CoinPriceUSD[] cpu;
    IVault vault;
    uint256 expireTimestamp;
}

struct FeeParams {
    CoinPriceUSD[] cpu;
    IVault vault;
    uint256 expireTimestamp;
    uint256 position;
    uint256 amount;
}
