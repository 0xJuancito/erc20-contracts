// SPDX-License-Identifier: MIT
pragma solidity >0.5.0;

interface IRescue {
  /**
   * @notice Rescue and transfer tokens locked in this contract
   * @param token The address of the token
   * @param to The address of the recipient
   * @param amount The amount of token to transfer
   **/
  function rescueTokens(address token, address to, uint256 amount) external;

  /**
   * @dev Emitted during the token rescue
   * @param tokenRescued The token which is being rescued
   * @param receiver The recipient which will receive the rescued token
   * @param amountRescued The amount being rescued
   **/
  event TokensRescued(
    address indexed tokenRescued,
    address indexed receiver,
    uint256 amountRescued
  );
}
