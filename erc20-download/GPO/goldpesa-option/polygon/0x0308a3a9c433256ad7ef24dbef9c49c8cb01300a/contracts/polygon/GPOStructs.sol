// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

contract GPOStructs {
    /// @notice GPO tokens swapped
    event TokensSwaped(
        address indexed purchaser,
        uint256 amountIn,
        uint256 amountOut,
        bool direction // false: GPO-X, true: X-GPO
    );

    /// @notice GPO tokens transferred from GPO Reserves
    event ReserveTokenTransfer(
        address indexed to,
        uint256 amount
    );

    /// @notice Whitelist wallet changes
    event WalletWhitelistChanged(
        address indexed wallet,
        bool whitelist
    );

    /// @notice Liquidity Pool parameters changes
    event PoolParametersChanged(
        address token,
        uint24 poolFee
    );

    /// @notice FreeTrade enabled/disabled
    event FreeTradeChanged(
        bool freeTrade
    );

    /// @notice Swap enabled/disabled
    event SwapPermChanged(
        bool swapPerm
    );

    /// @notice FeeOnSwap changes
    event FeeOnSwapChanged(
        uint24 feeOnSwap
    );

    /// @notice Fee Splits changes
    event FeeSplitsChanged(
        uint256 length,
        FeeSplit[] feeSplitsArray
    );

    /// @notice CapOnWallet changes
    event CapOnWalletChanged(
        uint256 capOnWallet
    );

    /// @notice FeeSplit stores the "recipient" wallet address and the respective percentage of the feeOnSwap which are to be sent 
    struct FeeSplit {
        address recipient;
        uint16 fee;
    }
}