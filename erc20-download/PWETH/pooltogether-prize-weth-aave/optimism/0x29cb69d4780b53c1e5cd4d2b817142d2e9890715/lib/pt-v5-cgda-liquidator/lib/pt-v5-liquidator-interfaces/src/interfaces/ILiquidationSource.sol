// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILiquidationSource {

  /**
   * @notice Emitted when a new liquidation pair is set for the given `tokenOut`.
   * @param tokenOut The token being liquidated
   * @param liquidationPair The new liquidation pair for the token
   */
  event LiquidationPairSet(address indexed tokenOut, address indexed liquidationPair);

  /**
   * @notice Get the available amount of tokens that can be swapped.
   * @param tokenOut Address of the token to get available balance for
   * @return uint256 Available amount of `token`
   */
  function liquidatableBalanceOf(address tokenOut) external returns (uint256);

  /**
   * @notice Transfers tokens to the receiver
   * @param sender Address that triggered the liquidation
   * @param receiver Address of the account that will receive `tokenOut`
   * @param tokenOut Address of the token being bought
   * @param amountOut Amount of token being bought
   */
  function transferTokensOut(
    address sender,
    address receiver,
    address tokenOut,
    uint256 amountOut
  ) external returns (bytes memory);

  /**
   * @notice Verifies that tokens have been transferred in.
   * @param tokenIn Address of the token being sold
   * @param amountIn Amount of token being sold
   * @param transferTokensOutData Data returned by the corresponding transferTokensOut call
   */
  function verifyTokensIn(
    address tokenIn,
    uint256 amountIn,
    bytes calldata transferTokensOutData
  ) external;

  /**
   * @notice Get the address that will receive `tokenIn`.
   * @param tokenIn Address of the token to get the target address for
   * @return address Address of the target
   */
  function targetOf(address tokenIn) external returns (address);

  /**
   * @notice Checks if a liquidation pair can be used to liquidate the given tokenOut from this source.
   * @param tokenOut The address of the token to liquidate
   * @param liquidationPair The address of the liquidation pair that is being checked
   * @return bool True if the liquidation pair can be used, false otherwise
   */
  function isLiquidationPair(address tokenOut, address liquidationPair) external returns (bool);
}
