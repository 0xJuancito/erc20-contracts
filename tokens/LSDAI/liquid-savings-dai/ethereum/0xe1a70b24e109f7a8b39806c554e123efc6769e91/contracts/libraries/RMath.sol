// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title RMath - math library
 * @notice based on MakerDAO's math function in DSRManager
 */
library RMath {
  // --- Math ---
  uint256 constant RAY = 10 ** 27;

  function rmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
    // always rounds down
    z = SafeMath.mul(x, y) / RAY;
  }

  function rdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
    // always rounds down
    z = SafeMath.mul(x, RAY) / y;
  }

  function rdivup(uint256 x, uint256 y) internal pure returns (uint256 z) {
    // always rounds up
    z = SafeMath.add(SafeMath.mul(x, RAY), SafeMath.sub(y, 1)) / y;
  }

  function rpow(uint256 x, uint256 n) internal pure returns (uint256 z) {
    assembly {
      switch x
      case 0 {
        switch n
        case 0 { z := RAY }
        default { z := 0 }
      }
      default {
        switch mod(n, 2)
        case 0 { z := RAY }
        default { z := x }
        let half := div(RAY, 2) // for rounding.
        for { n := div(n, 2) } n { n := div(n, 2) } {
          let xx := mul(x, x)
          if iszero(eq(div(xx, x), x)) { revert(0, 0) }
          let xxRound := add(xx, half)
          if lt(xxRound, xx) { revert(0, 0) }
          x := div(xxRound, RAY)
          if mod(n, 2) {
            let zx := mul(z, x)
            if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0, 0) }
            let zxRound := add(zx, half)
            if lt(zxRound, zx) { revert(0, 0) }
            z := div(zxRound, RAY)
          }
        }
      }
    }
  }
}
