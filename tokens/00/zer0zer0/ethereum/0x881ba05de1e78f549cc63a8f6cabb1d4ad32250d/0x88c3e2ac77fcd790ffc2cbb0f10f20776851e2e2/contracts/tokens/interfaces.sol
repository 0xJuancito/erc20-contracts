// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/interfaces/draft-IERC2612.sol";
import "@openzeppelin/contracts/governance/utils/IVotes.sol";
import "./extensions/IERC1046.sol";
import "./extensions/IERC1363.sol";

/// @custom:security-contact security@p00ls.com
interface IP00lsTokenBase is IERC20, IERC1046, IERC1363, IERC2612, IVotes
{
    function owner() external view returns (address);
    function setTokenURI(string calldata) external;
    function setName(address, string calldata) external;
}

/// @custom:security-contact security@p00ls.com
interface IP00lsTokenCreator is IP00lsTokenBase {
    function xCreatorToken() external view returns (IP00lsTokenXCreator);
    function merkleRoot() external view returns (bytes32);
    function isClaimed(uint256) external view returns (bool);
    function claim(uint256, address, uint256, bytes32[] calldata) external;
}

/// @custom:security-contact security@p00ls.com
interface IP00lsTokenXCreator is IP00lsTokenBase {
    function creatorToken() external view returns (IP00lsTokenCreator);
    function escrow() external view returns (address);
    function deposit(uint256) external;
    function withdraw(uint256) external;
    function depositFor(uint256, address) external;
    function withdrawTo(uint256, address) external;
    function valueToShares(uint256) external view returns (uint256);
    function sharesToValue(uint256) external view returns (uint256);
    function pastSharesToValue(uint256 shares, uint256 blockNumber) external view returns (uint256);
    function __delegate(address, address) external;
}
