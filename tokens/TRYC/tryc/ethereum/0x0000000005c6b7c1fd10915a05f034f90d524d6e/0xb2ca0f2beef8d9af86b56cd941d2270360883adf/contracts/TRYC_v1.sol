// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

/// @title TRYC Contract
/// @author Stoken/Paribu

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract TRYC_v1 is ERC20Upgradeable, OwnableUpgradeable, PausableUpgradeable {
    /// @dev Holds blacklisted addresses
    mapping (address => bool) private _blacklist;

    /// @dev Initializes contract, sets name and symbol of the token
    /// @param name Name of the token
    /// @param symbol Symbol of the token
    function initialize(string memory name, string memory symbol) external initializer {
        __ERC20_init(name,symbol);
        __Ownable_init_unchained();
        __Pausable_init_unchained();
    }

    /// @dev Returns token decimals
    /// @return uint8
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /// @dev Burns tokens, callable only by the owner
    /// @return bool
    function burn(uint256 amount) external onlyOwner returns (bool) {
        _burn(_msgSender(), amount);
        return true;
    }

    /// @dev Mints tokens, callable only by the owner
    /// @return bool
    function mint(address account, uint256 amount) external onlyOwner returns (bool) {
        _mint(account, amount);
        return true;
    }

    /// @dev Adds an address to blacklist
    /// @return bool
    function blacklist(address account) external onlyOwner returns (bool) {
        _blacklist[account] = true;
        return true;
    }

    /// @dev Removes an address from blacklist
    /// @return bool
    function unblacklist(address account) external onlyOwner returns (bool) {
        delete _blacklist[account];
        return true;
    }

    /// @dev Checks if an address is blacklisted
    /// @return bool
    function blacklisted(address account) public view virtual returns (bool) {
        return _blacklist[account];
    }

    /// @dev Pauses token transfers
    /// @return bool
    function pause() external onlyOwner whenNotPaused returns (bool) {
        _pause();
        return true;
    }

    /// @dev Unpauses token transfers
    /// @return bool
    function unpause() external onlyOwner whenPaused returns (bool) {
        _unpause();
        return true;
    }

    /** @dev Standard ERC20 hook,
    checks if transfer paused,
    checks from or to addresses is blacklisted
    */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        require(!paused(), "ERC20Pausable: token transfer while paused");
        require(!_blacklist[from], "Token transfer from blacklisted address");
        require(!_blacklist[to], "Token transfer to blacklisted address");
    }
}
