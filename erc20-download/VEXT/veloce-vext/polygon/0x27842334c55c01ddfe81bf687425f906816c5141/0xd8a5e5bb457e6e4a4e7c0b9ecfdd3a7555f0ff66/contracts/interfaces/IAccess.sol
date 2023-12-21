// SPDX-License-Identifier: agpl-3.0

pragma solidity 0.8.9;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/// @title Access interface
/// @notice Access is the main contract which stores the roles
abstract contract IAccess is ERC165 {
    /* ========== FUNCTIONS ========== */

    function userHasRole(
        bytes32 _role,
        address _address
    ) external view virtual returns (bool);

    function onlyGovernanceRole(address _caller) external view virtual;

    function onlyEmergencyRole(address _caller) external view virtual;

    function onlyTokenRole(address _caller) external view virtual;

    function onlyBoostRole(address _caller) external view virtual;

    function onlyRewardDropRole(address _caller) external view virtual;

    function onlyStakingRole(address _caller) external view virtual;

    function onlyStakingPauserRole(address _caller) external view virtual;

    function onlyStakingFactoryRole(address _caller) external view virtual;

    function onlyStakingManagerRole(address _caller) external view virtual;

    function executive() public pure virtual returns (bytes32);

    function admin() public pure virtual returns (bytes32);

    function deployer() public pure virtual returns (bytes32);

    function emergencyRole() public pure virtual returns (bytes32);

    function vextRole() public pure virtual returns (bytes32);

    function pauseRole() public pure virtual returns (bytes32);

    function governanceRole() public pure virtual returns (bytes32);

    function boostRole() public pure virtual returns (bytes32);

    function stakingRole() public pure virtual returns (bytes32);

    function rewardDropRole() public pure virtual returns (bytes32);

    function stakingFactoryRole() public pure virtual returns (bytes32);

    function stakingManagerRole() public pure virtual returns (bytes32);
}
