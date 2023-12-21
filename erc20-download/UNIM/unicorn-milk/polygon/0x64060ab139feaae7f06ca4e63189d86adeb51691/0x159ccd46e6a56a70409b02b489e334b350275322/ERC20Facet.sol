// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "ERC20WithCommonStorage.sol";
import "LibERC20.sol";
import "LibDiamond.sol";

/*
    Implementation of Erc20 with Diamond storage with some modifications
    https://github.com/bugout-dev/dao/blob/main/contracts/moonstream/ERC20WithCommonStorage.sol
 */
contract ERC20Facet is ERC20WithCommonStorage {
    constructor() {}

    function contractController() external view returns (address) {
        return LibERC20.erc20Storage().controller;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        require(
            recipient != address(this),
            "ERC20Facet: You can't send UNIM to the contract itself. In order to burn, use burn()"
        );
        super.transferFrom(sender, recipient, amount);
        return true;
    }

    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        require(
            recipient != address(this),
            "ERC20Facet: You can't send UNIM to the contract itself. In order to burn, use burn()"
        );
        super.transfer(recipient, amount);
        return true;
    }

    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, deducting from the caller's
     * allowance.
     *
     * See {ERC20-_burn} and {ERC20-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `amount`.
     */
    function burnFrom(address account, uint256 amount) public virtual {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(
            currentAllowance >= amount,
            "ERC20Facet: burn amount exceeds allowance"
        );
        unchecked {
            _approve(account, _msgSender(), currentAllowance - amount);
        }
        _burn(account, amount);
    }

    function mint(address account, uint256 amount) external {
        LibERC20.enforceIsController();
        _mint(account, amount);
    }

    function batchMint(address[] calldata accounts, uint256[] calldata amounts)
        external
    {
        LibERC20.enforceIsController();
        require(
            accounts.length == amounts.length,
            "ERC20Facet: accounts and amounts must be the same length"
        );
        for (uint256 i = 0; i < accounts.length; i++) {
            _mint(accounts[i], amounts[i]);
        }
    }

    function batchMintConstant(address[] calldata accounts, uint256 amount)
        external
    {
        LibERC20.enforceIsController();
        for (uint256 i = 0; i < accounts.length; i++) {
            _mint(accounts[i], amount);
        }
    }
}
