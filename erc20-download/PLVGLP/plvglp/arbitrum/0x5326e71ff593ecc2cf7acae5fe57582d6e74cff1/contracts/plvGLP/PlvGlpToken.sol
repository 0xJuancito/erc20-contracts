// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.9;

import '@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract PlvGlpToken is ERC4626, Ownable {
  uint256 public supplyCap;
  struct VaultParameters {
    bool canMint;
    bool canWithdraw;
    bool canRedeem;
    bool canDeposit;
  }

  VaultParameters public vaultParams;
  address public operator; // GlpDepositor

  constructor(address plsGLP) ERC4626(IERC20Metadata(plsGLP)) ERC20('Plutus Vault GLP', 'plvGLP') {
    vaultParams.canDeposit = true;
    vaultParams.canRedeem = true;
    supplyCap = 1_000_000 ether;
  }

  /** OVERRIDES */

  function redeem(
    uint256 shares,
    address receiver,
    address owner
  ) public override returns (uint256) {
    if (!vaultParams.canRedeem) revert NOT_ENABLED();
    if (msg.sender != operator) revert UNAUTHORIZED();

    return super.redeem(shares, receiver, owner);
  }

  function deposit(uint256 assets, address receiver) public override returns (uint256) {
    if (!vaultParams.canDeposit) revert NOT_ENABLED();
    if (msg.sender != operator) revert UNAUTHORIZED();
    if (totalSupply() + previewDeposit(assets) > supplyCap) revert SUPPLY_CAP_EXCEEDED();

    return super.deposit(assets, receiver);
  }

  function withdraw(
    uint256 assets,
    address receiver,
    address owner
  ) public override returns (uint256) {
    if (!vaultParams.canWithdraw) revert NOT_ENABLED();
    if (msg.sender != operator) revert UNAUTHORIZED();

    return super.redeem(assets, receiver, owner);
  }

  function mint(uint256 shares, address receiver) public override returns (uint256) {
    if (!vaultParams.canMint) revert NOT_ENABLED();
    if (msg.sender != operator) revert UNAUTHORIZED();

    return super.mint(shares, receiver);
  }

  /** OWNER FUNCTIONS */
  function setParams(
    bool _canMint,
    bool _canWithdraw,
    bool _canRedeem,
    bool _canDeposit
  ) external onlyOwner {
    vaultParams = VaultParameters({
      canMint: _canMint,
      canWithdraw: _canWithdraw,
      canRedeem: _canRedeem,
      canDeposit: _canDeposit
    });

    emit VaultParametersUpdated(_canMint, _canWithdraw, _canRedeem, _canDeposit);
  }

  function setSupplyCap(uint256 _newSupplyCap) external onlyOwner {
    emit SupplyCapUpdated(_newSupplyCap);
    supplyCap = _newSupplyCap;
  }

  function setOperator(address _newOperator) external onlyOwner {
    emit OperatorUpdated(_newOperator, operator);
    operator = _newOperator;
  }

  event VaultParametersUpdated(bool canMint, bool canWithdraw, bool canRedeem, bool canDeposit);
  event OperatorUpdated(address indexed _new, address indexed _old);
  event SupplyCapUpdated(uint256 _newCap);

  error NOT_ENABLED();
  error SUPPLY_CAP_EXCEEDED();
  error UNAUTHORIZED();
}
