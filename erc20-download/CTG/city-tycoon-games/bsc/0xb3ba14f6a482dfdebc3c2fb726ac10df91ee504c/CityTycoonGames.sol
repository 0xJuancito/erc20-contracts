// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ERC20.sol";

contract CityTycoonGames is ERC20 {
    constructor() ERC20("City Tycoon Games", "CTG") {
        _mint(msg.sender, 1_000_000_000 * (10**uint256(decimals())));
    }
}
