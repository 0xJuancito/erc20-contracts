// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.10;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Ownable } from "./Ownable.sol";

contract MaintenanceMode is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    bool public isMaintenanceMode = true;
    EnumerableSet.AddressSet private maintainers;

    event MaintainerAdded(address indexed account);
    event MaintainerRemoved(address indexed account);
    event MaintenanceModeUpdated(bool isMaintenanceMode);

    modifier maintenanceMode() {
      if (isMaintenanceMode) {
        require (maintainers.contains(msg.sender), "Maintenance mode: Only maintainers can transact");
      }
      _;
    }

    constructor(address owner) {
        maintainers.add(owner);
    }

    function addMaintainer(address account) external onlyOwner {
        require (maintainers.contains(account) == false, "Maintenance mode: The account is already a maintainer");
        maintainers.add(account);
        emit MaintainerAdded(account);
    }

    function removeMaintainer(address account) external onlyOwner {
        require (maintainers.contains(account), "Maintenance mode: The account is not a maintainer");
        maintainers.remove(account);
        emit MaintainerRemoved(account);
    }

    function setMaintenanceMode(bool _isMaintenanceMode) external onlyOwner {
        if (isMaintenanceMode != _isMaintenanceMode) {
            isMaintenanceMode = _isMaintenanceMode;
            emit MaintenanceModeUpdated(_isMaintenanceMode);
        }
    }

    function isMaintainer(address account) external view returns (bool) {
        return maintainers.contains(account);
    }

    function listMaintainers() external view returns (address[] memory) {
        return maintainers.values();
    }
}
