// SPDX-License-Identifier: agpl-3.0

pragma solidity 0.8.9;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/// @title Pause interface
abstract contract ISystemPause is ERC165 {
    /* ========== REVERT STATEMENTS ========== */

    error SystemPaused();
    error UnauthorisedAccess();
    error InvalidAddress();
    error InvalidModuleName();
    error UpdateStakingManagerAddress();
    error CallUnsuccessful(address contractAddress);

    /* ========== EVENTS ========== */

    event PauseStatus(uint indexed moduleId, bool isPaused);
    event NewModule(
        uint indexed moduleId,
        address indexed contractAddress,
        string indexed name
    );
    event UpdatedModule(
        uint indexed moduleId,
        address indexed contractAddress,
        string indexed name
    );

    /* ========== FUNCTIONS ========== */

    function setStakingManager(address _stakingManagerAddress) external virtual;

    function pauseModule(uint id) external virtual;

    function unPauseModule(uint id) external virtual;

    function createModule(
        string memory name,
        address _contractAddress
    ) external virtual;

    function updateModule(uint id, address _contractAddress) external virtual;

    function getModuleStatusWithId(
        uint id
    ) external view virtual returns (bool isActive);

    function getModuleStatusWithAddress(
        address _contractAddress
    ) external view virtual returns (bool isActive);

    function getModuleAddressWithId(
        uint id
    ) external view virtual returns (address module);

    function getModuleIdWithAddress(
        address _contractAddress
    ) external view virtual returns (uint id);

    function getModuleIdWithName(
        string memory name
    ) external view virtual returns (uint id);

    function getModuleNameWithId(
        uint id
    ) external view virtual returns (string memory name);
}
