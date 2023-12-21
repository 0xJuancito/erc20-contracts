// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./BaseOFTV2Initializable.sol";

abstract contract OFTV2Initializable is BaseOFTV2Initializable {
    uint internal constant ld2sdRate = 10 ** 8;

    /************************************************************************
     * public functions
     ************************************************************************/

    function token() public view virtual override returns (address) {
        return address(this);
    }

    function _ld2sdRate() internal view virtual override returns (uint) {
        return ld2sdRate;
    }
}
