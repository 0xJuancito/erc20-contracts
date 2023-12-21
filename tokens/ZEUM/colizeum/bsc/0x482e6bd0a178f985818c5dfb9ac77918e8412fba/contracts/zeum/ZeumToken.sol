// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

import "../interfaces/IZeumToken.sol";

/// @title ZEUM token on different chains
contract ZeumToken is IZeumToken, ERC20, AccessControlEnumerable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 public constant HARD_CAP = 1_000_000_000 * 10**18;

    uint256 internal _softCap;

    error SoftCapExceeded();
    error HardCapExceeded();
    error CurrentCirculationExceedsNewSoftCap();

    event SoftCapUpdated(uint256 previousCap, uint256 newSoftCap);

    constructor(
        address admin,
        string memory name,
        string memory symbol,
        uint256 softCap
    ) ERC20(name, symbol) {
        if (softCap > HARD_CAP) revert HardCapExceeded();

        _softCap = softCap;

        // Set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, admin);

        emit SoftCapUpdated(0, softCap);
    }

    function mint(address to, uint256 amount) external override onlyRole(MINTER_ROLE) {
        if (totalSupply() + amount > _softCap) revert SoftCapExceeded();

        _mint(to, amount);
    }

    function burn(address account, uint256 amount) external override onlyRole(MINTER_ROLE) {
        _burn(account, amount);
    }

    function setSoftCap(uint256 newSoftCap) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newSoftCap > HARD_CAP) revert HardCapExceeded();
        if (newSoftCap < totalSupply()) revert CurrentCirculationExceedsNewSoftCap();

        emit SoftCapUpdated(_softCap, newSoftCap);

        _softCap = newSoftCap;
    }

    function getSoftCap() external view override returns (uint256) {
        return _softCap;
    }
}
