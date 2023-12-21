// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Address.sol";
import "./SafeERC20.sol";

abstract contract ERC20Fallback {
    using Address for address;
    using SafeERC20 for IERC20;

    event TokenWithdrawn(IERC20 token, address indexed to, uint256 value);

    /**
    * @dev Faalback Redeem tokens. The ability to redeem token whe okenst are accidentally sent to the contract
    * @param token_ Address of the IERC20 token
    * @param to_ address Recipient of the recovered tokens
    * @param amount_ Number of tokens to be emitted
    */
    function fallbackRedeem(IERC20 token_,  address to_, uint256 amount_) external {
      _prevalidateFallbackRedeem(token_, to_, amount_);

      _processFallbackRedeem(token_, to_, amount_);
      emit TokenWithdrawn(token_, to_, amount_);

      _updateFallbackRedeem(token_, to_, amount_);
      _postValidateFallbackRedeem(token_, to_, amount_);
    }

    /**
    * @dev Validation of an fallback redeem. Use require statements to revert state when conditions are not met.
    * Use `super` in contracts that inherit from TokenEscrow to extend their validations.
    * Example from TokenEscrow.sol's _prevalidateFallbackRedeem method:
    *     super._prevalidateFallbackRedeem(token, payee, amount);
    *    
    * @param token_ The token address of IERC20 token
    * @param to_ Address performing the token deposit
    * @param amount_ Number of tokens deposit
    *
    * Requirements:
    *
    * - `msg.sender` must be owner.
    * - `token` cannot be the zero address.
    * - `to` cannot be the zero address.
    * - this address must have a token balance of at least `amount`.
    */
    function _prevalidateFallbackRedeem(IERC20 token_,  address to_, uint256 amount_) internal virtual view {
      require(address(token_) != address(0), "ERC20Fallback: token is the zero address");
      require(to_ != address(0), "ERC20Fallback: cannot recover to zero address");
      require(amount_ != 0, "ERC20Fallback: amount is 0");
      
      uint256 amount = token_.balanceOf(address(this));
      require(amount >= amount_, "ERC20Fallback: no token to release");
      this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
    }

    /**
    * @dev Executed when fallbackRedeem has been validated and is ready to be executed. Doesn't necessarily emit/send
    * tokens.
    * @param token_ The token address of IERC20 token
    * @param to_ Address where the token sent to
    * @param amount_ Number of tokens deposit
    */
    function _processFallbackRedeem(IERC20 token_,address to_, uint256 amount_) internal virtual {
      _deliverTokens(token_, to_, amount_);
    }

    /**
    * @dev Override for extensions that require an internal state to check for validity fallback redeem,
    * etc.)
    * @param token_ The token address of IERC20 token
    * @param to_ Address where the token sent to
    * @param amount_ Number of tokens deposit
    */
    function _updateFallbackRedeem(IERC20 token_, address to_, uint256 amount_) internal virtual {
      // solhint-disable-previous-line no-empty-blocks
    }

    /**
    * @dev Validation of an executed fallback redeem. Observe state and use revert statements to undo rollback when valid
    * conditions are not met.
    * @param token_ The token address of IERC20 token
    * @param to_ Address where the token sent to
    * @param amount_ Number of tokens deposit
    */
    function _postValidateFallbackRedeem(IERC20 token_, address to_, uint256 amount_) internal virtual view {
      // solhint-disable-previous-line no-empty-blocks
    }

    /**
     * @dev Source of tokens. Override this method to modify the way in which the tokenescrow ultimately gets and sends
     * its tokens.
     * @param token_ The token address of IERC20 token
     * @param to_ Address where the token sent to
     * @param amount_ Number of tokens to be emitted
     */
    function _deliverTokens(IERC20 token_, address to_, uint256 amount_) internal virtual returns (bool) {
      token_.safeTransfer(to_, amount_);
      return true;
    }
}