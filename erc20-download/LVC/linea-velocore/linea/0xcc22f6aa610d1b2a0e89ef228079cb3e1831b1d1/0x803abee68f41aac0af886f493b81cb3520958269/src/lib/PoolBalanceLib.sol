// SPDX-License-Identifier: AUNLICENSED
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";

// a pool's balances are stored as two uint128;
// the only difference between them is that new emissions are credited into the gauge balance.
// the pool can use them in any way they want.

type PoolBalance is bytes32;

library PoolBalanceLib {
    using PoolBalanceLib for PoolBalance;
    using SafeCast for uint256;
    using SafeCast for int256;

    function gaugeHalf(PoolBalance self) internal pure returns (uint256) {
        return uint128(bytes16(PoolBalance.unwrap(self)));
    }

    function poolHalf(PoolBalance self) internal pure returns (uint256) {
        return uint128(uint256(PoolBalance.unwrap(self)));
    }

    function pack(uint256 a, uint256 b) internal pure returns (PoolBalance) {
        uint128 a_ = uint128(a);
        uint128 b_ = uint128(b);
        require(b == b_ && a == a_, "overflow");
        return PoolBalance.wrap(bytes32(bytes16(a_)) | bytes32(uint256(b_)));
    }

    function credit(PoolBalance self, int256 dGauge, int256 dPool) internal pure returns (PoolBalance) {
        return pack(
            (int256(uint256(self.gaugeHalf())) + dGauge).toUint256(),
            (int256(uint256(self.poolHalf())) + dPool).toUint256()
        );
    }

    function credit(PoolBalance self, int256 dPool) internal pure returns (PoolBalance) {
        return pack(self.gaugeHalf(), (int256(uint256(self.poolHalf())) + dPool).toUint256());
    }
}
