// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import '@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

import { IRateProvider } from './Interfaces.sol';
import { IErrors } from '../external/Common.sol';

interface IPlsRdntTokenV2 is IErrors {
  function burn(uint256 _amount) external;

  event OperatorUpdated(address _newOperator, address _operator);
  event Burned(uint _amount);
}

contract PlsRdntTokenV2 is
  IPlsRdntTokenV2,
  IRateProvider,
  Initializable,
  ERC4626Upgradeable,
  Ownable2StepUpgradeable,
  UUPSUpgradeable
{
  using EnumerableSet for EnumerableSet.AddressSet;

  EnumerableSet.AddressSet private operators;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(IERC20 _asset) public initializer {
    __ERC4626_init(_asset);
    __ERC20_init('Plutus RDNT V2', 'plsRDNT');

    __Ownable2Step_init();
    __Ownable_init(msg.sender);
    __UUPSUpgradeable_init();
  }

  function getOperators() public view returns (address[] memory) {
    return operators.values();
  }

  /**
   * @return value of plsRDNT in terms of dLP
   */
  function getRate() external view returns (uint) {
    return convertToAssets(1e18);
  }

  function withdraw(uint256, address, address) public pure override returns (uint256) {
    revert FAILED('PlsRdntToken: Not allowed');
  }

  function mint(uint256, address) public pure override returns (uint256) {
    revert FAILED('PlsRdntToken: Not allowed');
  }

  function burn(uint256 _amount) external {
    if (!operators.contains(msg.sender)) revert UNAUTHORIZED();
    _burn(msg.sender, _amount);

    emit Burned(_amount);
  }

  function redeem(uint256 shares, address receiver, address owner) public override returns (uint256) {
    if (!operators.contains(msg.sender)) revert UNAUTHORIZED();
    return super.redeem(shares, receiver, owner);
  }

  function deposit(uint256 assets, address receiver) public override returns (uint256) {
    if (!operators.contains(msg.sender)) revert UNAUTHORIZED();
    return super.deposit(assets, receiver);
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

  function addOperator(address _newOperator) external onlyOwner {
    bool added = operators.add(_newOperator);
    emit OperatorUpdated(_newOperator, address(0));

    if (!added) {
      revert FAILED('PlsRdntToken: operator exists');
    }
  }

  function removeOperator(address _existingOperator) external onlyOwner {
    bool removed = operators.remove(_existingOperator);
    emit OperatorUpdated(address(0), _existingOperator);

    if (!removed) {
      revert FAILED('PlsRdntToken: operator !exists');
    }
  }
}
