// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./utils/ERC20.sol";

contract BridgedToken is ERC20 {

    address private migrationAuthority;
    address private pendingMigratorAuthority;
    address private immutable bridge;

    modifier onlyMinter() {
        require(msg.sender == bridge || msg.sender == migrationAuthority, "Unauthorized");
        _;
    }

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals,
        address _bridge,
        bool hasMigration
    ) ERC20(name, symbol, decimals) {
        require(_bridge != address(0), "Bridge cannot be addresss 0");
        bridge = _bridge;
        if (hasMigration) {
            migrationAuthority = msg.sender;
        }
    }

    // Token Migrations

    function passMigratorAuthority(address _newAuthority) external {
        require(msg.sender == migrationAuthority, "Unauthorized");
        pendingMigratorAuthority = _newAuthority;
    }

    function acceptMigratorAuthority() external {
        require(msg.sender == pendingMigratorAuthority, "Unauthorized");
        migrationAuthority = pendingMigratorAuthority;
        pendingMigratorAuthority = address(0);
    }

    // mint/burn functions

    function mint(address _user, uint256 _amount) external onlyMinter {
        _mint(_user, _amount);
    }

    function burn(address _user, uint256 _amount) external onlyMinter {
        _burn(_user, _amount);
    }
    
    // State getters

    function getBridge() external view returns (address) {
        return bridge;
    }

    function getMigrator() external view returns (address) {
        return migrationAuthority;
    }
}