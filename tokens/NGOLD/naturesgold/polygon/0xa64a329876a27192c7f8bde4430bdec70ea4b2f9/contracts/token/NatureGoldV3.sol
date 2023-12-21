// contracts/NatureGold.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "../BP/interfaces/IBotPrevention.sol";

contract NatureGoldV3 is ERC20, Pausable, Ownable, AccessControl {
    bytes32 private constant MINTER_ROLE = keccak256("MINTER_ROLE");

    address private constant BURN_ADDRESS =
        0x000000000000000000000000000000000000dEaD;

    // address of bot prevention
    address public _bpAddr;
    bool public _isEnableBP;

    // Define the supply of NatureGold: 388,793,750
    uint256 constant INITIAL_SUPPLY = 388_793_750 * (10 ** 18);
    uint256 public _burntAmount;

    constructor(address bpAddr) ERC20("NaturesGold Token", "NGOLD") {
        _bpAddr = bpAddr;
        _isEnableBP = true;

        _mint(_msgSender(), INITIAL_SUPPLY);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    // Function to enable/disable bot prevention
    function setEnableBP(bool isEnableBP) external onlyOwner {
        _isEnableBP = isEnableBP;
    }

    // Function to update bot prevention address
    function setBPAddress(address bpAddr) external onlyOwner {
        _bpAddr = bpAddr;
    }

    /**
     * @dev called by the owner to pause, triggers stopped state
     */
    function pause() external virtual onlyOwner whenNotPaused {
        _pause();
    }

    /**
     * @dev called by the owner to unpause, returns to normal state
     */
    function unpause() external virtual onlyOwner whenPaused {
        _unpause();
    }

    /**
     * @dev Creates `amount` new tokens for `to`.
     *
     * See {ERC20-_mint}.
     *
     * Requirements:
     *
     * - the caller must have the `MINTER_ROLE`.
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function transfer(
        address _to,
        uint256 _value
    ) public virtual override whenNotPaused returns (bool) {
        _transfer(_msgSender(), _to, _value);
        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public virtual override whenNotPaused returns (bool) {
        uint256 currentAllowance = allowance(_from, _msgSender());
        require(currentAllowance >= _value, "exceed allowance");
        unchecked {
            _approve(_from, _msgSender(), currentAllowance - _value);
        }

        _transfer(_from, _to, _value);
        return true;
    }

    /// @dev overrides transfer function
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        require(amount > 0, "amount is zero");

        if (recipient == BURN_ADDRESS) {
            super._burn(sender, amount);
            _burntAmount += amount;
            return;
        }

        if (_isEnableBP && _bpAddr != address(0x0)) {
            IBotPrevention(_bpAddr).protect(sender, recipient, amount);
        }

        super._transfer(sender, recipient, amount);
    }
}
