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

    event XMSSupportRatioUpdate(uint256 _xmsSupportRatio);
    event USDMUpdate(address indexed _usdm);
    event XMSUpdate(address indexed _xms);
    event GenesisGroupUpdate(address indexed _genesisGroup);
    event TokenAllocation(address indexed _to, uint256 _amount);
    event TokenApprove(address indexed _to, uint256 _amount);
    event GenesisPeriodComplete(uint256 _timestamp);

    // ----------- Governor only state changing api -----------

    function setXMSSupportRatio(uint256 _xmsSupportRatio) external;

    function setUSDM(address token) external;

    function setXMS(address token) external;

    function setGenesisGroup(address _genesisGroup) external;

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

    function setApprovedPairAndContract(address _pair, address _contract)
        external;

    function removeApprovedPairAndContract(address _pair, address _contract)
        external;

    // ----------- Genesis Group only state changing api -----------

    function completeGenesisGroup() external;

    // ----------- Getters -----------

    function getApprovedPairsLength() external view returns (uint256);

    function getApprovedContractsLength(address _pair)
        external
        view
        returns (uint256);

    function approvedPairs(uint256 idx) external view returns (address);

    function approvedPairExisted(address pair) external view returns (bool);

    function approvedContracts(address pair, uint256 idx)
        external
        view
        returns (address);

    function approvedContractExisted(address pair, address _contract)
        external
        view
        returns (bool);

    function xmsSupportRatio() external view returns (uint256);

    function xmsSupportRatioPrecision() external view returns (uint256);

    function usdm() external view returns (IUSDMToken);

    function xms() external view returns (IXMSToken);

    function genesisGroup() external view returns (address);

    function hasGenesisGroupCompleted() external view returns (bool);
}
