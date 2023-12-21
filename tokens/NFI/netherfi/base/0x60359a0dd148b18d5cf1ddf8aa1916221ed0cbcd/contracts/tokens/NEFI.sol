// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../tokens/MintableBaseToken.sol";

contract NFI is MintableBaseToken {
    constructor() public MintableBaseToken("NetherFi", "NFI", 0) {
    }

    function id() external pure returns (string memory _name) {
        return "NFI";
    }
}