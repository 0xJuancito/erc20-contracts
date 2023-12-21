pragma solidity 0.8.19;

// SPDX-License-Identifier: MIT

library StructLibrary {
    struct Params {
        string name;
        string symbol;
        uint112 totalSupply;
        uint48 liquidityPercentage;
        address marketingReceiver;
        address devReceiver;
        uint48 marketingTaxBuy;
        uint48 devTaxBuy;
        uint48 lpTaxBuy;
        uint48 revShareTaxBuy;
        uint48 marketingTaxSell;
        uint48 devTaxSell;
        uint48 lpTaxSell;
        uint48 revShareTaxSell;
        uint128 transactionLimit;
        uint128 walletLimit;
        uint48 gasLimit;
    }
}