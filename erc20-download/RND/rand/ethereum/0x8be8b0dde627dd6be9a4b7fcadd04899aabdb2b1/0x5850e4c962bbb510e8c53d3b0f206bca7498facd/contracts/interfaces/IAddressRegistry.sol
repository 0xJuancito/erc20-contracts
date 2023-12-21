// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface IAddressRegistry {
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

    function ECOSYSTEM_RESERVE() external view returns (string memory);

    function GOVERNANCE() external view returns (string memory);

    function INVESTOR_NFT() external view returns (string memory);

    function MULTISIG() external view returns (string memory);

    function PAUSER_ROLE() external view returns (bytes32);

    function POOL_TOKEN() external view returns (string memory);

    function RAND_TOKEN() external view returns (string memory);

    function SAFETY_MODULE() external view returns (string memory);

    function VESTING_CONTROLLER() external view returns (string memory);

    function VESTING_CONTROLLER_SIGNER() external view returns (string memory);

    function getAddressOf(
        string memory name
    ) external view returns (address contractAddress);

    function getAllAddress(
        string memory name
    ) external view returns (address[] memory);

    function getRegistryList() external view returns (string[] memory);

    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    function grantRole(bytes32 role, address account) external;

    function hasRole(
        bytes32 role,
        address account
    ) external view returns (bool);

    function initialize(address _multisigVault) external;

    function pause() external;

    function paused() external view returns (bool);

    function proxiableUUID() external view returns (bytes32);

    function renounceRole(bytes32 role, address account) external;

    function revokeRole(bytes32 role, address account) external;

    function setNewAddress(
        string memory name,
        address contractAddress
    ) external returns (bool);

    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    function unpause() external;

    function updateAddress(
        string memory name,
        address contractAddress
    ) external;

    function upgradeTo(address newImplementation) external;

    function upgradeToAndCall(
        address newImplementation,
        bytes memory data
    ) external;
}
