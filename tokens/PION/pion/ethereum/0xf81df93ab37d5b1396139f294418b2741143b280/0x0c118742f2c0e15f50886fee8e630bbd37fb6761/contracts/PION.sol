// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./Token.sol";

contract PION is Token {
    function initialize() external initializer {
        Token._initialize("PioneerNetwork", "PION");
    }

    function name() public view virtual override returns (string memory) {
        return "PION Network";
    }
}
