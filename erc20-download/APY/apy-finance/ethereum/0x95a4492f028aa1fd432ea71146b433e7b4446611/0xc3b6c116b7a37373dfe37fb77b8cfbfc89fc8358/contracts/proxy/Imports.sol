// SPDX-License-Identifier: BUSDL-1.1
pragma solidity 0.6.11;

import {Initializable} from "./Initializable.sol";
import {
    OwnableUpgradeSafe
} from "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import {
    ERC20UpgradeSafe
} from "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import {
    ReentrancyGuardUpgradeSafe
} from "@openzeppelin/contracts-ethereum-package/contracts/utils/ReentrancyGuard.sol";
import {
    PausableUpgradeSafe
} from "@openzeppelin/contracts-ethereum-package/contracts/utils/Pausable.sol";
import {AccessControlUpgradeSafe} from "./AccessControlUpgradeSafe.sol";

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/ProxyAdmin.sol";
import {
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";

/* Aliases don't persist so we can't rename them here, but you should
 * rename them at point of import with the "UpgradeSafe" prefix, e.g.
 * import {Address as AddressUpgradeSafe} etc.
 */
import {
    Address
} from "@openzeppelin/contracts-ethereum-package/contracts/utils/Address.sol";
import {
    SafeMath
} from "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import {
    SignedSafeMath
} from "@openzeppelin/contracts-ethereum-package/contracts/math/SignedSafeMath.sol";
