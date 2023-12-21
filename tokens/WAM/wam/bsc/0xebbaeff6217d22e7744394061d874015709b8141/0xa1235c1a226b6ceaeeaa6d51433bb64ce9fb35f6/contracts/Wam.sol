// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract WAM is ERC20Upgradeable {
    
    constructor() {}   
    
    /**
     * @dev Mints total supply of tokens and transfers them to `tokenHolder`.
     *
     * See {__ERC20_init}.
     */
    function initialize(address presale, address team, address advisors, address marketing, address development, address rewardpool, address liquidity, address reserve) initializer external {
        __ERC20_init("WAM", "WAM");

        _mint(presale, 142_000_000e18);
        _mint(team, 146_000_000e18);
        _mint(advisors, 50_000_000e18);
        _mint(marketing, 70_000_000e18);
        _mint(development, 50_000_000e18);
        _mint(rewardpool, 400_000_000e18);
        _mint(liquidity, 92_000_000e18);
        _mint(reserve, 50_000_000e18);
    }

}
