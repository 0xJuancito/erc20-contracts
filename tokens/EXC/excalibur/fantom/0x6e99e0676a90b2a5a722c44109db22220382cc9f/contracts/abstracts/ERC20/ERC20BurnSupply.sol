// SPDX-License-Identifier: MIT

pragma solidity =0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../interfaces/tokens/IERC20BurnSupply.sol";

/**
 * ERC20 implementation including burn supply management
 */
abstract contract ERC20BurnSupply is ERC20, IERC20BurnSupply {
  using SafeMath for uint256;

  uint256 private _burnSupply;

  function burnSupply() external view override returns (uint256) {
    return _burnSupply;
  }

  /**
   * @dev Extends default ERC20 to add amount to burnSupply
   */
  function _burn(address account, uint256 amount) internal virtual override {
    super._burn(account, amount);
    _burnSupply = _burnSupply.add(amount);
  }
}
