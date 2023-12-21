// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import "./ICore.sol";

/// @title CoreRef interface
/// @author USDM Protocol
interface ICoreRef {
    // ----------- Events -----------

    event CoreUpdate(address indexed core);

    // ----------- Governor only state changing api -----------

    function setCore(address) external;

    function pause() external;

    function unpause() external;

    // ----------- Getters -----------

    function core() external view returns (ICore);

    function usdm() external view returns (IUSDMToken);

    function xms() external view returns (IXMSToken);

    function usdmBalance() external view returns (uint256);

    function xmsBalance() external view returns (uint256);
}
