// SPDX-License-Identifier: J-J-J-JENGA!!!
pragma solidity ^0.7.4;

import "./IERC20.sol";
import "./IDarkMagicTransferGate.sol";

interface IGatedERC20 is IERC20
{
    function transferGate() external view returns (IDarkMagicTransferGate);

    function setTransferGate(IDarkMagicTransferGate _transferGate) external;
}