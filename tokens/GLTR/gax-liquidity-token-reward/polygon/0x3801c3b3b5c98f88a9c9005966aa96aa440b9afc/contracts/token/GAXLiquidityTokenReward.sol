// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract GAXLiquidityTokenReward is ERC20Permit {
  using SafeERC20 for IERC20;

  constructor()
    ERC20("GAX Liquidity Token Reward", "GLTR")
    ERC20Permit("GAX Liquidity Token Reward")
  {
    _mint(msg.sender, 1e12 * 1e18); // 1 trillion
  }

  /// @notice Sends tokens mistakenly sent to this contract to the Aavegotchi DAO treasury
  function recoverERC20(address _token, uint256 _value)
    external
    virtual
  {
    IERC20(_token).safeTransfer(
      0x6fb7e0AAFBa16396Ad6c1046027717bcA25F821f,
      _value
    );
  }
}
