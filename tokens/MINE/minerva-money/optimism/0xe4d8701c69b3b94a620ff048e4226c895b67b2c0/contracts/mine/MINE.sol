// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../tokens/MintableBaseToken.sol";

contract MINE is MintableBaseToken {
    constructor() public MintableBaseToken("Minerva", "MINE", 1330000) {}

    function id() external pure returns (string memory _name) {
        return "MINE";
    }
}
