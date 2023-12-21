// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../tokens/MintableBaseToken.sol";

contract KTX is MintableBaseToken {
    constructor() public MintableBaseToken("KTX Community Token", "KTC", 0) {}

    function id() external pure returns (string memory _name) {
        return "KTX";
    }
}
