//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./ERC20VestableInTimestamp.sol";

contract FlourishingAIToken is ERC20VestableInTimestamp {
    uint8 private constant DECIMALS = 18;
    uint256 private constant TOKEN_WEI = 10**uint256(DECIMALS);

    uint256 private constant INITIAL_WHOLE_TOKENS = uint256(55 * (10**6)); // 55 million
    uint256 private constant INITIAL_SUPPLY =
        uint256(INITIAL_WHOLE_TOKENS) * uint256(TOKEN_WEI);

    constructor(address admin) ERC20("Flourishing AI Token", "AI") {
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(GRANTOR_ROLE, admin);
        addWhiteList(admin);

        _mint(admin, INITIAL_SUPPLY);
    }

    function mint(address to, uint256 amount) public onlyAdmin {
        _mint(to, amount);
    }
}
