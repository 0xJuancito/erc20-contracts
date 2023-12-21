// SPDX-License-Identifier: WTFPL
pragma solidity 0.8.6;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

abstract contract SecurityPresetUpgradeable is
    OwnableUpgradeable,
    AccessControlEnumerableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeMathUpgradeable for uint256;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    bool private _isEnabled = true;

    function __SecurityPresetUpgradeable_init() public initializer {
        OwnableUpgradeable.__Ownable_init_unchained();
        ContextUpgradeable.__Context_init_unchained();
        ERC165Upgradeable.__ERC165_init_unchained();
        AccessControlUpgradeable.__AccessControl_init_unchained();
        AccessControlEnumerableUpgradeable.__AccessControlEnumerable_init_unchained();
        PausableUpgradeable.__Pausable_init_unchained();
        __SecurityPresetUpgradeable_init_unchained();
    }

    function __SecurityPresetUpgradeable_init_unchained() internal initializer {
        AccessControlUpgradeable._setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        AccessControlUpgradeable._setupRole(PAUSER_ROLE, _msgSender());
    }

    modifier whenEnabled() {
        require(_isEnabled == true, "This is disabled");
        _;
    }

    /**
     * @dev Pauses all token transfers.
     *
     * See {ERC20Pausable} and {Pausable-_pause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function pause() external virtual whenNotPaused onlyRole(PAUSER_ROLE) {
        PausableUpgradeable._pause();
    }

    /**
     * @dev Unpauses all token transfers.
     *
     * See {ERC20Pausable} and {Pausable-_unpause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function unpause() external virtual whenPaused onlyRole(PAUSER_ROLE) {
        PausableUpgradeable._unpause();
    }

    function toggleEnabled() external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_isEnabled == true) {
            _isEnabled = false;
        } else if (_isEnabled == false) {
            _isEnabled = true;
        } else {
            revert();
        }
    }

    receive() external payable {}

    fallback() external payable {}

    uint256[50] private __gap;
}
