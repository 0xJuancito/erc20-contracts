pragma solidity 0.8.4;

/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Written by 0xMotoko (0xmotoko@pm.me)
 * Copyright (C) 2021 Yamato Protocol (DeFiGeek Community Japan)
 */

//solhint-disable max-line-length
//solhint-disable no-inline-assembly

import "./Currency.sol";

/**
 * @author 0xMotoko
 * @title CToken (Convertible Token).
 * @notice Very stable.
 */
contract CJPY is Currency {
    constructor() Currency("Convertible JPY Token", "CJPY") {}
}
