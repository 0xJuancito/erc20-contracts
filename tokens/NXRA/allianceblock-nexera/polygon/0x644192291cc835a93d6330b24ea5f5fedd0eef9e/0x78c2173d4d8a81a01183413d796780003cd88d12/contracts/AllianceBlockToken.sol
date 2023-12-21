// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/presets/ERC20PresetMinterPauserUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20SnapshotUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";

contract AllianceBlockToken is ERC20PresetMinterPauserUpgradeable, ERC20SnapshotUpgradeable, ERC20PermitUpgradeable {
    uint256 private constant VERSION = 1;

    // The cap or max total supply of the token.
    uint256 private _cap;

    event BatchMint(address indexed sender, uint256 recipientsLength, uint256 totalValue);

    constructor() initializer {}

    function init(string memory name, string memory symbol, address admin, uint256 cap_) public initializer {
        __ERC20_init_unchained(name, symbol);
        __ERC20Snapshot_init_unchained();
        __ERC20Permit_init(name);
        __Pausable_init_unchained();
        __AllianceBlockToken_init_unchained(cap_);
        // We don't use __ERC20PresetMinterPauser_init_unchained to avoid giving permisions to _msgSender
        require(admin != address(0), "NXRA: Admin can't be zero address");
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(MINTER_ROLE, admin);
        _setupRole(PAUSER_ROLE, admin);
    }

    function __AllianceBlockToken_init_unchained(uint256 cap_) internal onlyInitializing {
        require(cap_ > 0, "NXRA: cap is 0");
        _cap = cap_;
    }

    // Update balance and/or total supply snapshots before the values are modified. This is implemented
    // in the _beforeTokenTransfer hook, which is executed for _mint, _burn, and _transfer operations.
    // Avoid direct token transfers to this contract
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20PresetMinterPauserUpgradeable, ERC20SnapshotUpgradeable, ERC20Upgradeable) {
        require(to != address(this), "NXRA: Token transfer to this contract");
        super._beforeTokenTransfer(from, to, amount);
    }

    /**
     * @dev Get the current snapshotId
     */
    function getCurrentSnapshotId() public view returns (uint256) {
        return _getCurrentSnapshotId();
    }

    /**
     * @dev Creates a new snapshot and returns its snapshot id.
     *
     * Emits a {Snapshot} event that contains the same id.
     *
     * {_snapshot} is `internal` and you have to decide how to expose it externally. Its usage may be restricted to a
     * set of accounts, for example using {AccessControl}, or it may be open to the public.
     */
    function snapshot() public returns (uint256) {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "NXRA: Snapshot invalid role");
        require(!paused(), "NXRA: Contract paused");
        return _snapshot();
    }

    /**
     * @dev Returns the cap on the token's total supply.
     */
    function cap() external view virtual returns (uint256) {
        return _cap;
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
    function pause() public override {
        super.pause();
        _snapshot();
    }

    /// @dev Returns the version of the contract.
    function contractVersion() external pure returns (uint256) {
        return VERSION;
    }

    /**
     * @dev Mints multiple values for multiple receivers
     */
    function batchMint(address[] calldata recipients, uint256[] calldata values) public returns (bool) {
        require(hasRole(MINTER_ROLE, _msgSender()), "NXRA: Batch mint invalid role");

        uint256 recipientsLength = recipients.length;
        require(recipientsLength == values.length, "NXRA: Batch mint not same legth");

        uint256 totalValue = 0;
        for (uint256 i = 0; i < recipientsLength;) {
            super._mint(recipients[i], values[i]);
            unchecked {
                // Overflow not possible: totalValue + amount is at most totalSupply + amount, which is checked above.
                totalValue += values[i];
            }
            unchecked { i++; }
        }

        require(totalSupply() <= _cap, "NXRA: cap exceeded");
        emit BatchMint(_msgSender(), recipientsLength, totalValue);
        return true;
    }

    /**
     * @dev See {ERC20-_mint}.
     * @dev Checks if cap is reached and calls normal _mint.
     */
    function _mint(address account, uint256 amount) internal override {
        require(totalSupply() + amount <= _cap, "NXRA: cap exceeded");
        super._mint(account, amount);
    }

}
