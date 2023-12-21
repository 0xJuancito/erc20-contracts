// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


// Based on https://github.com/Lossless-Cash/lossless-v2/blob/master/contracts/LERC20.sol#L33
interface ILosslessController {
    function beforeTransfer(address sender, address recipient, uint256 amount) external;

    function beforeTransferFrom(address msgSender, address sender, address recipient, uint256 amount) external;

    function beforeApprove(address sender, address spender, uint256 amount) external;

    function beforeIncreaseAllowance(address msgSender, address spender, uint256 addedValue) external;

    function beforeDecreaseAllowance(address msgSender, address spender, uint256 subtractedValue) external;
}
