// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import './SafeMath.sol';

library ExtraMath {
    using SafeMath for uint;

    function divCeil(uint _a, uint _b) internal pure returns(uint) {
        if (_a.mod(_b) > 0) {
            return (_a / _b).add(1);
        }
        return _a / _b;
    }

    function toUInt8(uint _a) internal pure returns(uint8) {
        require(_a <= uint8(-1), 'uint8 overflow');
        return uint8(_a);
    }

    function toUInt32(uint _a) internal pure returns(uint32) {
        require(_a <= uint32(-1), 'uint32 overflow');
        return uint32(_a);
    }

    function toUInt96(uint _a) internal pure returns(uint96) {
        require(_a <= uint96(-1), 'uint96 overflow');
        return uint96(_a);
    }

    function toUInt120(uint _a) internal pure returns(uint120) {
        require(_a <= uint120(-1), 'uint120 overflow');
        return uint120(_a);
    }

    function toUInt128(uint _a) internal pure returns(uint128) {
        require(_a <= uint128(-1), 'uint128 overflow');
        return uint128(_a);
    }
}
