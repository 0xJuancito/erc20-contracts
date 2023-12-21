// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

interface ILeetSwapV2Pair {
    function factory() external view returns (address);

    function fees() external view returns (address);

    function transferFrom(
        address src,
        address dst,
        uint256 amount
    ) external returns (bool);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function burn(address to)
        external
        returns (uint256 amount0, uint256 amount1);

    function mint(address to) external returns (uint256 liquidity);

    function getReserves()
        external
        view
        returns (
            uint256 _reserve0,
            uint256 _reserve1,
            uint256 _blockTimestampLast
        );

    function getAmountOut(uint256, address) external view returns (uint256);

    function current(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function stable() external view returns (bool);

    function balanceOf(address) external view returns (uint256);

    //LP token pricing
    function sample(
        address tokenIn,
        uint256 amountIn,
        uint256 points,
        uint256 window
    ) external view returns (uint256[] memory);

    function quote(
        address tokenIn,
        uint256 amountIn,
        uint256 granularity
    ) external view returns (uint256);

    function claimFeesFor(address account)
        external
        returns (uint256 claimed0, uint256 claimed1);

    function claimFees() external returns (uint256 claimed0, uint256 claimed1);

    function claimableFeesFor(address account)
        external
        returns (uint256 claimed0, uint256 claimed1);

    function claimableFees()
        external
        returns (uint256 claimed0, uint256 claimed1);
}
