// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC20} from "./ERC20.sol";
import {IERC20} from "./IERC20.sol";
import {KUMA_PROTOCOL_ERRORS} from "./Errors.sol";
import {ERC4626} from "./ERC4626.sol";

contract WrappedRebaseToken is ERC4626 {
    /**
     * A simple implementation of the ERC4626 spec
     * Sets the underlyingToken, name, and symbol constructor arguments for ERC20 and ERC4626
     * @param asset The rebase token that this contract wraps around, will be passed into the ERC4626 constructor
     * @param name The name of the Wrapped Rebase Token; will be passed into the ERC20 constructor
     * @param symbol The symbol of the Wrapped Rebase Token; will be passed into the ERC20 constructor
     */
    constructor(IERC20 asset, string memory name, string memory symbol) ERC20(name, symbol) ERC4626(asset) {
        if (address(asset) == address(0)) {
            revert KUMA_PROTOCOL_ERRORS.CANNOT_SET_TO_ADDRESS_ZERO();
        }
    }
}
