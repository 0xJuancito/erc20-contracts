// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import "./IPermissions.sol";
import "../interfaces/IXMSToken.sol";
import "../interfaces/IUSDMToken.sol";

/// @title Core Interface
/// @author USDM Protocol
interface ICore is IPermissions {
    // ----------- Events -----------

    event XMSSupportRatioUpdate(uint256 xmsSupportRatio);
    event USDMUpdate(address indexed usdm);
    event XMSUpdate(address indexed xms);
    event GenesisGroupUpdate(address indexed genesisGroup);
    event TokenAllocation(address indexed to, uint256 amount);
    event TokenApprove(address indexed to, uint256 amount);
    event GenesisPeriodComplete(uint256 timestamp);

    // ----------- Governor only state changing api -----------

    function setXMSSupportRatio(uint256) external;

    function setUSDM(address) external;

    function setXMS(address) external;

    function setGenesisGroup(address) external;

    function allocateXMS(address to, uint256 amount) external;

    function allocateToken(
        address token,
        address to,
        uint256 amount
    ) external;

    function approveXMS(address to, uint256 amount) external;

    function approveToken(
        address token,
        address to,
        uint256 amount
    ) external;

    // ----------- Genesis Group only state changing api -----------

    function completeGenesisGroup() external;

    // ----------- Getters -----------

    function xmsSupportRatio() external view returns (uint256);

    function xmsSupportRatioPrecision() external view returns (uint256);

    function usdm() external view returns (IUSDMToken);

    function xms() external view returns (IXMSToken);

    function genesisGroup() external view returns (address);

    function hasGenesisGroupCompleted() external view returns (bool);
}
