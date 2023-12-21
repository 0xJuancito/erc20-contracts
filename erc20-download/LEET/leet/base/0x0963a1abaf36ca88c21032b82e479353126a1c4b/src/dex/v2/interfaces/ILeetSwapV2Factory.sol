// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

interface ILeetSwapV2Factory {
    function allPairsLength() external view returns (uint256);

    function isPair(address pair) external view returns (bool);

    function pairCodeHash() external pure returns (bytes32);

    function getPair(
        address tokenA,
        address token,
        bool stable
    ) external view returns (address);

    function createPair(
        address tokenA,
        address tokenB,
        bool stable
    ) external returns (address);

    function createPair(address tokenA, address tokenB)
        external
        returns (address);

    function getInitializable()
        external
        view
        returns (
            address token0,
            address token1,
            bool stable
        );

    function protocolFeesShare() external view returns (uint256);

    function protocolFeesRecipient() external view returns (address);

    function tradingFees(address pair, address to)
        external
        view
        returns (uint256);

    function isPaused() external view returns (bool);
}
