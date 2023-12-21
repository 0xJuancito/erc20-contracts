// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IERC20Upgradeable} from "src/oz/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IERC20PermitUpgradeable} from
    "@oz/contracts-upgradeable/token/ERC20/extensions/draft-IERC20PermitUpgradeable.sol";

interface IRebornTokenDef {
    /// @dev revert when the caller is not minter
    error NotMinter();
    /// @dev disable upgrade
    error CannotUpgradeAnyMore();
    /// @dev disable transfer
    error TransferBlocked();
    /// @dev emit when minter is updated

    event MinterUpdate(address minter, bool valid);
    /// @dev block user to prevent transfer
    event BlockUser(address user, bool isBlocked);
}

interface IRebornToken is IERC20Upgradeable, IERC20PermitUpgradeable, IRebornTokenDef {
    function mint(address to, uint256 amount) external;
}
