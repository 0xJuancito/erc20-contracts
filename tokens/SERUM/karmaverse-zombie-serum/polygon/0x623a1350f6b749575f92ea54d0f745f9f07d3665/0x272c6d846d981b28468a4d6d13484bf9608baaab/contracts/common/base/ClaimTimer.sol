//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.4;

abstract contract ClaimTimer {

    mapping(address => uint64) private timer;

    function _getClaimTs(address account) internal view returns(uint64) {
        return timer[account];
    }

    function _setClaimTs(address account, uint64 ts) internal {
        timer[account] = ts;
    }
}