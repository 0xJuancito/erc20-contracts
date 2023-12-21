// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.4;

import {ERC20Detailed} from "../libs/ERC20Detailed.sol";

/**
 * @notice implementation of the BEND token contract
 * @author Bend
 */
contract BendToken is ERC20Detailed {
    string internal constant NAME = "Bend Token";
    string internal constant SYMBOL = "BEND";
    uint8 internal constant DECIMALS = 18;

    function initialize(address misc, uint256 _amount) external initializer {
        __ERC20Detailed_init(NAME, SYMBOL, DECIMALS);
        _mint(misc, _amount);
    }
}
