// SPDX-License-Identifier: UNLICENCED
pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";


library Babylonian {
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
        // else z = 0
    }
}



contract lpHelper {
    using SafeMath for uint256;

    function calculateSwapInAmount(uint256 reserveIn, uint256 userIn)
    public
    pure
    returns (uint256)
    {
        return
        Babylonian
        .sqrt(
            reserveIn.mul(userIn.mul(3988000) + reserveIn.mul(3988009))
        )
        .sub(reserveIn.mul(1997)) / 1994;
    }
}
