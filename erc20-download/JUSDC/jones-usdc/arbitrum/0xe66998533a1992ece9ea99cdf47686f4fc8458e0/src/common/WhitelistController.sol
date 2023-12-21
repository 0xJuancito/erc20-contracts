// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {IWhitelistController} from "../interfaces/IWhitelistController.sol";

contract WhitelistController is IWhitelistController, AccessControl, Ownable {
    mapping(bytes32 => IWhitelistController.RoleInfo) public roleInfo;
    mapping(address => bytes32) public userInfo;
    mapping(bytes32 => bool) public roleExists;

    bytes32 private constant INTERNAL = bytes32("INTERNAL");
    bytes32 private constant WHITELISTED_CONTRACTS = bytes32("WHITELISTED_CONTRACTS");
    uint256 public constant BASIS_POINTS = 1e12;

    constructor() {
        IWhitelistController.RoleInfo memory DEFAULT_ROLE = IWhitelistController.RoleInfo(false, false, 3e10, 97e8);

        bytes32 defaultRole = bytes32(0);
        createRole(defaultRole, DEFAULT_ROLE);
    }

    function updateDefaultRole(uint256 _jglpRetention, uint256 _jusdcRetention) public onlyOwner {
        IWhitelistController.RoleInfo memory NEW_DEFAULT_ROLE =
            IWhitelistController.RoleInfo(false, false, _jglpRetention, _jusdcRetention);

        bytes32 defaultRole = bytes32(0);
        createRole(defaultRole, NEW_DEFAULT_ROLE);
    }

    function hasRole(bytes32 role, address account)
        public
        view
        override(IWhitelistController, AccessControl)
        returns (bool)
    {
        return super.hasRole(role, account);
    }

    function isInternalContract(address _account) public view returns (bool) {
        return hasRole(INTERNAL, _account);
    }

    function isWhitelistedContract(address _account) public view returns (bool) {
        return hasRole(WHITELISTED_CONTRACTS, _account);
    }

    function addToRole(bytes32 ROLE, address _account) public onlyOwner validRole(ROLE) {
        _addRoleUser(ROLE, _account);
    }

    function addToInternalContract(address _account) public onlyOwner {
        _grantRole(INTERNAL, _account);
    }

    function addToWhitelistContracts(address _account) public onlyOwner {
        _grantRole(WHITELISTED_CONTRACTS, _account);
    }

    function bulkAddToWhitelistContracts(address[] calldata _accounts) public onlyOwner {
        uint256 length = _accounts.length;
        for (uint8 i = 0; i < length;) {
            _grantRole(WHITELISTED_CONTRACTS, _accounts[i]);
            unchecked {
                ++i;
            }
        }
    }

    function createRole(bytes32 _roleName, IWhitelistController.RoleInfo memory _roleInfo) public onlyOwner {
        roleExists[_roleName] = true;
        roleInfo[_roleName] = _roleInfo;
    }

    function _addRoleUser(bytes32 _role, address _user) internal {
        userInfo[_user] = _role;
    }

    function getUserRole(address _user) public view returns (bytes32) {
        return userInfo[_user];
    }

    function getDefaultRole() public view returns (IWhitelistController.RoleInfo memory) {
        bytes32 defaultRole = bytes32(0);
        return getRoleInfo(defaultRole);
    }

    function getRoleInfo(bytes32 _role) public view returns (IWhitelistController.RoleInfo memory) {
        return roleInfo[_role];
    }

    function removeUserFromRole(address _user) public onlyOwner {
        bytes32 zeroRole = bytes32(0x0);
        userInfo[_user] = zeroRole;
    }

    function removeFromInternalContract(address _account) public onlyOwner {
        _revokeRole(INTERNAL, _account);
    }

    function removeFromWhitelistContract(address _account) public onlyOwner {
        _revokeRole(WHITELISTED_CONTRACTS, _account);
    }

    function bulkRemoveFromWhitelistContract(address[] calldata _accounts) public onlyOwner {
        uint256 length = _accounts.length;
        for (uint8 i = 0; i < length;) {
            _revokeRole(WHITELISTED_CONTRACTS, _accounts[i]);
            unchecked {
                ++i;
            }
        }
    }

    modifier validRole(bytes32 _role) {
        require(roleExists[_role], "Role does not exist!");
        _;
    }
}
