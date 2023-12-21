pragma solidity 0.8.4;

/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Written by 0xMotoko (0xmotoko@pm.me)
 * Copyright (C) 2021 Yamato Protocol (DeFiGeek Community Japan)
 */

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface ICurrency {
    /**
     * @dev mint token for recipient. Assuming onlyGovernance
     */
    function mint(address to, uint256 amount) external;

    /**
     * @dev burn token for recipient. Assuming onlyGovernance
     */
    function burn(address account, uint256 amount) external;
}
