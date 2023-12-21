// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/BEP20.sol";

contract N1Token is BEP20 {
    mapping(address => bool) adminList;

    modifier onlyAdmins() {
        require(adminList[msg.sender], "Only Admins");
        _;
    }

    constructor() public BEP20("NFTify", "N1") {
        adminList[msg.sender] = true;
    }

    /**
     * @dev Set `account` as admin of contract
     */
    function setAdmin(address account, bool value) external onlyOwner {
        adminList[account] = value;
    }

    /**
     * @dev Check `account` is in `adminList` or not
     */
    function isAdmin(address account) public view returns (bool) {
        return adminList[account];
    }

    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {BEP20-_burn}.
     */
    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, deducting from the caller's
     * allowance.
     *
     * See {BEP20-_burnFrom}.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `amount`.
     */
    function burnFrom(address account, uint256 amount) public virtual {
      _burnFrom(account, amount);
    }

    /**
     * @dev Creates amount tokens and assigns them to account, increasing
     * the total supply.
     *
     * Requirements
     *
     * - account cannot be the zero address.
     */
    function mint(address account, uint256 amount) external onlyAdmins {
        _mint(account, amount);
    }
}