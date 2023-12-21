// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ICNFI is IERC20 {
  function mint(address user, uint256 amount) external;
}
