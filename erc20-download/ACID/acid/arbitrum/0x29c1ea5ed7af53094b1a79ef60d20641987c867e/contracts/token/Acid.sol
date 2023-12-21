// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity =0.8.18;

import "./MintableToken.sol";

contract Acid is MintableToken {
    constructor() ERC20("Acid", "ACID") {}
}
