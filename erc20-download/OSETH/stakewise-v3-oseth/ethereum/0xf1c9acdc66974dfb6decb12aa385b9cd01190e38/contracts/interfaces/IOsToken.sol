// SPDX-License-Identifier: BUSL-1.1

pragma solidity =0.8.22;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC20Permit} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {IERC5267} from '@openzeppelin/contracts/interfaces/IERC5267.sol';

/**
 * @title IOsToken
 * @author StakeWise
 * @notice Defines the interface for the OsToken contract
 */
interface IOsToken is IERC20, IERC20Metadata, IERC20Permit, IERC5267 {
  /**
   * @notice Emitted when a controller is updated
   * @param controller The address of the controller
   * @param registered Whether the controller is registered or not
   */
  event ControllerUpdated(address indexed controller, bool registered);

  /**
   * @notice Returns whether controller is registered or not
   * @param controller The address of the controller
   * @return Whether the controller is registered or not
   */
  function controllers(address controller) external view returns (bool);

  /**
   * @notice Mint OsToken. Can only be called by the controller.
   * @param account The address of the account to mint OsToken for
   * @param value The amount of OsToken to mint
   */
  function mint(address account, uint256 value) external;

  /**
   * @notice Burn OsToken. Can only be called by the controller.
   * @param account The address of the account to burn OsToken for
   * @param value The amount of OsToken to burn
   */
  function burn(address account, uint256 value) external;

  /**
   * @notice Enable or disable the controller. Can only be called by the contract owner.
   * @param controller The address of the controller
   * @param registered Whether the controller is registered or not
   */
  function setController(address controller, bool registered) external;
}
