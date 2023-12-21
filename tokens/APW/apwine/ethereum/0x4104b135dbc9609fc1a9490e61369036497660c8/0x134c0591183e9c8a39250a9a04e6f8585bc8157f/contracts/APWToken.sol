pragma solidity >=0.7.0 <0.8.0;

import "@openzeppelin/contracts-upgradeable/presets/ERC20PresetMinterPauserUpgradeable.sol";

/**
 * @title APW token contract
 * @notice Governance token of the APWine protocol
 */
contract APWToken is ERC20PresetMinterPauserUpgradeable {
    /**
     * @notice Intializer
     * @param _APWINEDAO the address of the owner address
     */
    function initialize(address _APWINEDAO) public initializer {
        super.initialize("APWine Token", "APW");
        _setupRole(DEFAULT_ADMIN_ROLE, _APWINEDAO);
    }
}
