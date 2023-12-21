// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/AccessControl.sol';
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

interface ILiquidityRestrictor {
  function assureLiquidityRestrictions(address from, address to) external returns (bool allow, string memory message);
}

interface IAntisnipe {
  function assureCanTransfer(address sender, address from, address to, uint256 amount) external returns (bool response);
}

contract LFCToken is AccessControl, ERC20Permit {

  event Minted(address indexed recipient, uint amount, string reason);
  event Burnt(address indexed burner, uint amount, string reason);

  bytes32 public constant MINTER_ROLE = keccak256('MINTER_ROLE');

  uint256 private immutable _cap = 100_000_000 * 1e9;

  IAntisnipe public antisnipe = IAntisnipe(address(0));
  ILiquidityRestrictor public liquidityRestrictor = ILiquidityRestrictor(address(0));

  bool public antisnipeEnabled = true;
  bool public liquidityRestrictionEnabled = true;

  event AntisnipeDisabled(uint256 timestamp, address disabler);
  event LiquidityRestrictionDisabled(uint256 timestamp, address disabler);
  event AntisnipeAddressChanged(address newAntisnipeAddress);
  event LiquidityRestrictionAddressChanged(address newLiquidityRestrictionAddress);

  constructor() ERC20("Life Coin", "LFC") ERC20Permit("Life Coin") {
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(MINTER_ROLE, msg.sender);
  }

  function decimals() public view override returns (uint8) {
    return 9;
  }

  function cap() public view virtual returns (uint256) {
    return _cap;
  }

  function addMinter(address newMinter) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _grantRole(MINTER_ROLE, newMinter);
  }

  function removeMinter(address existedMinter) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _revokeRole(MINTER_ROLE, existedMinter);
  }

  function mint(address recipient, uint256 amount, string memory reason) public onlyRole(MINTER_ROLE) {
    require(ERC20.totalSupply() + amount <= cap(), "cap exceeded");
    _mint(recipient, amount);
    emit Minted(recipient, amount, reason);
  }

  function burn(uint256 amount, string memory reason) public {
    _burn(_msgSender(), amount);
    emit Burnt(_msgSender(), amount, reason);
  }

  function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
    if (from == address(0) || to == address(0)) return;

    if (liquidityRestrictionEnabled && address(liquidityRestrictor) != address(0)) {
      (bool allow, string memory message) = liquidityRestrictor.assureLiquidityRestrictions(from, to);
      require(allow, message);
    }

    if (antisnipeEnabled && address(antisnipe) != address(0)) {
      require(antisnipe.assureCanTransfer(msg.sender, from, to, amount));
    }
  }

  function setAntisnipeDisable() external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(antisnipeEnabled);
    antisnipeEnabled = false;
    emit AntisnipeDisabled(block.timestamp, msg.sender);
  }

  function setLiquidityRestrictorDisable() external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(liquidityRestrictionEnabled);
    liquidityRestrictionEnabled = false;
    emit LiquidityRestrictionDisabled(block.timestamp, msg.sender);
  }

  function setAntisnipeAddress(address addr) external onlyRole(DEFAULT_ADMIN_ROLE) {
    antisnipe = IAntisnipe(addr);
    emit AntisnipeAddressChanged(addr);
  }

  function setLiquidityRestrictionAddress(address addr) external onlyRole(DEFAULT_ADMIN_ROLE) {
    liquidityRestrictor = ILiquidityRestrictor(addr);
    emit LiquidityRestrictionAddressChanged(addr);
  }
}
