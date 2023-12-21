// UstxRoles.sol
// Based on OpenZeppelin contracts v2.5.1
// SPDX-License-Identifier: MIT
// solhint-disable-next-line
pragma solidity ^0.5.0;

import "./Context.sol";
import "./Roles.sol";

contract UstxRoles is Context {
    using Roles for Roles.Role;

    event AdminAdded(address indexed account);
    event AdminRemoved(address indexed account);
    event MinterAdded(address indexed account);
    event MinterRemoved(address indexed account);

    Roles.Role private _administrators;
    uint256 private _numAdmins;
    uint256 private _minAdmins;
    Roles.Role private _minters;

    constructor (uint256 minAdmins) internal {
        _addAdmin(_msgSender());
        _addMinter(_msgSender());
        _minAdmins = minAdmins;
    }

    modifier onlyAdmin() {
        require(isAdmin(_msgSender()), "Roles: caller does not have the Admin role");
        _;
    }

    function isAdmin(address account) public view returns (bool) {
        return _administrators.has(account);
    }

    function addAdmin(address account) public onlyAdmin {
        _addAdmin(account);
    }

    function renounceAdmin() public {
        require(_numAdmins>_minAdmins, "There must always be a minimum number of admins in charge");
        _removeAdmin(_msgSender());
    }

    function _addAdmin(address account) internal {
        _administrators.add(account);
        _numAdmins++;
        emit AdminAdded(account);
    }

    function _removeAdmin(address account) internal {
        _administrators.remove(account);
        _numAdmins--;
        emit AdminRemoved(account);
    }

    modifier onlyMinter() {
        require(isMinter(_msgSender()), "Roles: caller does not have the Minter role");
        _;
    }

    function isMinter(address account) public view returns (bool) {
        return _minters.has(account);
    }

    function addMinter(address account) public onlyAdmin {
        _addMinter(account);
    }

    function removeMinter(address account) public onlyAdmin {
        _removeMinter(account);
    }

    function _addMinter(address account) internal {
        _minters.add(account);
        emit MinterAdded(account);
    }

    function _removeMinter(address account) internal {
        _minters.remove(account);
        emit MinterRemoved(account);
    }
}
