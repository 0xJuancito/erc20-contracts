// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../tokens/MintableBaseToken.sol";

contract FUL is MintableBaseToken {
    constructor() MintableBaseToken("FUL", "FUL", 0) {
    }

    function id() external pure returns (string memory _name) {
        return "FUL";
    }
}
