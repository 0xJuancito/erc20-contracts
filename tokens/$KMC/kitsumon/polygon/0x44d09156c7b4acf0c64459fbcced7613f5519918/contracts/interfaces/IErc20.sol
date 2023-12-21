// SPDX-License-Identifier: WTFPL
pragma solidity 0.8.6;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

interface IErc20 is IERC20Upgradeable, IERC20MetadataUpgradeable, IAccessControlEnumerableUpgradeable {
    function mint(address account, uint256 amount) external;
}
