// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract Capped {
    uint256 internal cap_;

    event SetCap(uint256 cap);

    function _setCapInternal(uint256 _cap) internal {
        require(_cap != cap_, "_setCapInternal: Cannot set the same cap");
        cap_ = _cap;
        emit SetCap(_cap);
    }

    function cap() external view returns (uint256) {
        return cap_;
    }
}
