// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CarbonWrappedERC20.sol";

/**
* @title CarbonTokenArbi - Carbon Token for Arbitrum
*
* @dev Carbon Token (SWTH)
*/
contract CarbonTokenArbi is CarbonWrappedERC20 {
  constructor(address lockProxyAddress) 
  CarbonWrappedERC20(lockProxyAddress, "Carbon Token", "SWTH") {
  }

  /**
    * @dev Returns the number of decimals used to get its user representation.
    * For example, if `decimals` equals `2`, a balance of `505` tokens should
    * be displayed to a user as `5.05` (`505 / 10 ** 2`).
    *
    * NOTE: This information is only used for _display_ purposes: it in
    * no way affects any of the arithmetic of the contract, including
    * {IERC20-balanceOf} and {IERC20-transfer}.
    */
  function decimals() public view virtual override returns (uint8) {
      return 8;
  }
}
