// SPDX-License-Identifier: MIT
pragma solidity =0.8.18;

import "./interfaces/IOshiTokenLogic.sol";
import {BaseTokenLogic} from "./BaseTokenLogic.sol";

contract OshiTokenLogic is
    BaseTokenLogic,
    IOshiTokenLogic
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev J : トークンを一括送金する
     * @dev E : batch transfer of this token
     *
     * @param batchObj  list of recipient & amount
     */
    function bulkTransfer(BatchObject[] calldata batchObj) external {
        for (uint i = 0; i < batchObj.length; i++) {
            require(
                batchObj[i].recipient != address(0),
                "cannot send token to zero address"
            );
            require(batchObj[i].amount > 0, "amount have to be positive");
            _transfer(msg.sender, batchObj[i].recipient, batchObj[i].amount);
        }
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}
