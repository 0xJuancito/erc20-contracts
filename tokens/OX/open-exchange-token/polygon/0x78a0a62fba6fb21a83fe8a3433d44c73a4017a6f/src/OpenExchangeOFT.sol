// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {OFT} from "../lib/solidity-examples/contracts/token/oft/OFT.sol";

contract OpenExchangeOFT is OFT {
    constructor(
        address _lzEndpoint
    ) OFT("Open Exchange Token", "OX", _lzEndpoint) {}

    function burn(uint256 amount) public {
        _burn(_msgSender(), amount);
    }
}
