// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract EGoldToken is AccessControl, ERC20Snapshot, Pausable, ReentrancyGuard {
    using SafeMath for uint256;
    using Address for address;
    bytes32 public constant PAUSE_ROLE = keccak256("PAUSE_ROLE");

    bytes32 public constant SNAPSHOT_ROLE = keccak256("SNAPSHOT_ROLE");

    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    bytes32 public constant LIMIT_ROLE = keccak256("LIMIT_ROLE");

    mapping(address => bool) private frozen;

    mapping(address => bool) private whitelist;

    bool private isWhitelist;

    uint256 public volumeLimit;

    bool public volumeLimitSwitch;

    uint256 public holdLimit;

    bool public holdLimitSwitch;

    constructor(string memory name_, string memory symbol_ , address _to, address _DFA) AccessControl() ERC20Snapshot() ERC20(name_, symbol_) {
        _setupRole(DEFAULT_ADMIN_ROLE, _DFA);
        _setRoleAdmin(PAUSE_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(SNAPSHOT_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(BURNER_ROLE, DEFAULT_ADMIN_ROLE);

        _mint(_to, 21000000000000000000000000);
    }

    function createSnapshot() external onlyRole(SNAPSHOT_ROLE) returns (uint256) {
        return _snapshot();
    }

    function pauseToken() external onlyRole(PAUSE_ROLE) returns (bool) {
        _pause();
        return true;
    }

    function unpauseToken() external onlyRole(PAUSE_ROLE) returns (bool) {
        _unpause();
        return true;
    }

    function burn(address _to, uint256 _value) external onlyRole(BURNER_ROLE) returns (bool) {
        _burn(_to, _value);
        return true;
    }

    function setVolumeLimit(uint256 _volumeLimit , bool _volumeLimitSwitch ) external virtual onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        volumeLimit = _volumeLimit;
        volumeLimitSwitch = _volumeLimitSwitch;
        return true;
    }

    function freeze(address _to) external virtual onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        frozen[_to] = true;
        return true;
    }

    function unfreeze(address _to) external virtual onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        frozen[_to] = false;
        return true;
    }

    function enableWhitelist() external virtual onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        isWhitelist = true;
        return true;
    }

    function disableWhitelist() external virtual onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        isWhitelist = true;
        return true;
    }

    function setWhitelist(address _to) external virtual onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        whitelist[_to] = true;
        return true;
    }

    function unsetWhitelist(address _to) external virtual onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        whitelist[_to] = false;
        return true;
    }

    function setholdLimit(uint256 _amt , bool _holdLimitswitch ) external virtual onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        holdLimit = _amt;
        holdLimitSwitch = _holdLimitswitch;
        return true;
    }

    function isFrozen(address _to) external view virtual returns (bool) {
        return frozen[_to];
    }

    function fetchWhitelist(address _to) external view virtual returns (bool) {
        return whitelist[_to];
    }

    function fetchWhitelistEnabled() external view virtual returns (bool) {
        return isWhitelist;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override nonReentrant {
        super._beforeTokenTransfer(from, to, amount);
        require(!paused(), "ERC20Pausable: token transfer while paused");
        require(frozen[from] == false, "ERC20Blockable: Token is frozen by admin"); // Blacklist
        if ( to.isContract() == true && isWhitelist == true ) {
            require( whitelist[to] == true , "ERC20Blockable: Not whitelisted contract for use"); // Whitelist of contracts if whitelisting is enabled
        }
        if( holdLimitSwitch == true ){
            require( balanceOf(to) <= holdLimit, "ERC20Blockable: HoldLimit Exceeded" ); // Hold Limit
        }
        if ( volumeLimitSwitch == true ){
            require( volumeLimit > amount , "ERC20Blockable: Volume limit exceeded"); // Volume Limit
        }
    }
}
