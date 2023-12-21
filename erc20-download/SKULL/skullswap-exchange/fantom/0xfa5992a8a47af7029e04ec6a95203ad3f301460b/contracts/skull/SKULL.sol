// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../tokens/MintableBaseToken.sol";

contract SKULL is MintableBaseToken {
    constructor() public MintableBaseToken("Skull Token", "SKULL", 7000000 ether) {}

    function id() external pure returns (string memory _name) {
        return "SKULL";
    }
}
