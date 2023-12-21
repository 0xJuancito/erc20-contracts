// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.7/contracts/utils/Context.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.7/contracts/access/AccessControl.sol";

contract EpicLeagueDeployer is Context, AccessControl {
    
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");

    constructor(address deployer) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DEPLOYER_ROLE, msg.sender);
        _grantRole(DEPLOYER_ROLE, deployer);
    }

    function deployBridgeToken(
        address owner,
        address minter,
        string memory name,
        string memory symbol,
        uint8 decimals
    ) external onlyRole(DEPLOYER_ROLE) returns (address) {
        return address(new ERC20(owner, minter, name, symbol, decimals, true));
    }
}