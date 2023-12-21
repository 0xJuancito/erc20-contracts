// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

import "@delegatecall/utils/contracts/AntiBot.sol";
import "@delegatecall/utils/contracts/Withdrawable.sol";

import "@delegatecall/vesting/contracts/IVestable.sol";
import { WithSupervisedTransfers } from "@delegatecall/utils/contracts/ERC20/WithSupervisedTransfers.sol";

contract AlaskaGoldRush is ERC20, ERC20Burnable, ERC20Permit, Withdrawable, IVestable, WithSupervisedTransfers, AntiBot {
    modifier protectedWithdrawal() override {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _;
    }

    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) ERC20Permit(name) {
        _mint(_msgSender(), initialSupply);
    }

    function transfer(address to, uint256 amount) public override onlyAllowedTransfer returns (bool) {
        return super.transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override onlyAllowedTransferFrom transactionThrottler(from, to, amount) returns (bool) {
        return super.transferFrom(from, to, amount);
    }

    function supportsVestableInterface() external pure override returns (bool) {
        return true;
    }

    /**
     * @dev Side effect that is called after valut is created.
     *
     * In the initial phase of vesting, the token manages transfers. A newly created vault needs permission to transfer tokens.
     */
    function onVaultCreated(address vault) external override {
        if (hasRole(SUPERVISED_TRANSFER_MANAGER_ROLE, _msgSender())) allowTransferBy(vault);
    }

    /**
     * @dev Side effect that is called after vesting is created.
     *
     * In the initial phase of vesting, the token manages transfers.
     * A newly created vesting needs permission to transfer tokens and to grant rights to vaults that are being created.
     */
    function onVestingCreated(address vesting) external override {
        if (hasRole(SUPERVISED_TRANSFER_ADMIN_ROLE, _msgSender())) addSupervisedTransferManager(vesting);
    }
}
