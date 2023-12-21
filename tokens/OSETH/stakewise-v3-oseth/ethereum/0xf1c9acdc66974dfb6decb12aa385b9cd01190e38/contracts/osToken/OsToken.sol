// SPDX-License-Identifier: BUSL-1.1

pragma solidity =0.8.22;

import {Ownable2Step, Ownable} from '@openzeppelin/contracts/access/Ownable2Step.sol';
import {ERC20Permit, IERC20Permit, ERC20} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol';
import {IOsToken} from '../interfaces/IOsToken.sol';
import {Errors} from '../libraries/Errors.sol';

/**
 * @title OsToken
 * @author StakeWise
 * @notice OsToken is an over-collateralized staked token
 */
contract OsToken is Ownable2Step, ERC20Permit, IOsToken {
  address private immutable _vaultController;

  /// @inheritdoc IOsToken
  mapping(address controller => bool enabled) public override controllers;

  /**
   * @dev Constructor
   * @param _owner The address of the contract owner
   * @param vaultController The address of the OsTokenVaultController contract
   * @param _name The name of the ERC20 token
   * @param _symbol The symbol of the ERC20 token
   */
  constructor(
    address _owner,
    address vaultController,
    string memory _name,
    string memory _symbol
  ) ERC20(_name, _symbol) ERC20Permit(_name) Ownable(_owner) {
    if (vaultController == address(0)) revert Errors.ZeroAddress();
    _vaultController = vaultController;
  }

  /**
   * @dev Throws if called by any account other than the controller.
   */
  modifier onlyController() {
    if (msg.sender != _vaultController && !controllers[msg.sender]) revert Errors.AccessDenied();
    _;
  }

  /// @inheritdoc IOsToken
  function mint(address account, uint256 value) external override onlyController {
    _mint(account, value);
  }

  /// @inheritdoc IOsToken
  function burn(address account, uint256 value) external override onlyController {
    _burn(account, value);
  }

  /// @inheritdoc IERC20Permit
  function nonces(
    address owner
  ) public view virtual override(ERC20Permit, IERC20Permit) returns (uint256) {
    return super.nonces(owner);
  }

  /// @inheritdoc IOsToken
  function setController(address controller, bool enabled) external override onlyOwner {
    if (controller == address(0)) revert Errors.ZeroAddress();
    controllers[controller] = enabled;
    emit ControllerUpdated(controller, enabled);
  }
}
