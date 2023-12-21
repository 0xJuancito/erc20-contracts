// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "../contracts/EmptyGap.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @dev ZARP Stablecoin ERC20 contract.
 *
 * ZARP Stablecoin is a standard ERC20 contract with a couple of unique additions.
 *
 * We use OpenZeppelin as far as possible for well-known and tested functionality.
 *
 * We implement ERC20Burnable, Pausable, and AccessControl. All as UUPSUpgradeable.
 *
 * We add two new roles: VERIFIER_ROLE & BURNER_ROLE. These are both related to
 * our on-chain KYC controls. We will only *mint* to addresses that are verified,
 * and only verified addresses can send tokens to us for *burning*. If a non-verified
 * address tries to burn, we will revert. As part of verification we do KYC checks
 * and connect banking details to an address. An {AddressVerificationChanged} event
 * is emitted whenever we verify an address.
 *
 * We implement an EmptyGap, since we have various features that we are
 * testing on testnets, and wanted to ensure we can upgrade forward and backwards
 * between those and what we have on mainnet.
 */
contract Zarp is
  Initializable,
  ERC20Upgradeable,
  ERC20BurnableUpgradeable,
  PausableUpgradeable,
  AccessControlUpgradeable,
  EmptyGap,
  UUPSUpgradeable
{
  mapping(address => bool) private _verified;
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
  bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
  bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

  event AddressVerificationChanged(address indexed account, address indexed sender, bool verificationStatus);

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize() public initializer {
    __ERC20_init("ZARP Stablecoin", "ZARP");
    __ERC20Burnable_init();
    __Pausable_init();
    __AccessControl_init();
    __ERC20FlashMint_init();
    __UUPSUpgradeable_init();

    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(PAUSER_ROLE, msg.sender);
    _grantRole(MINTER_ROLE, msg.sender);
    _grantRole(UPGRADER_ROLE, msg.sender);
    _grantRole(VERIFIER_ROLE, msg.sender);
    _grantRole(BURNER_ROLE, msg.sender);
  }

  function pause() public onlyRole(PAUSER_ROLE) {
    _pause();
  }

  function unpause() public onlyRole(PAUSER_ROLE) {
    _unpause();
  }

  function verify(address account) public whenNotPaused onlyRole(VERIFIER_ROLE) {
    _verified[account] = true;
    emit AddressVerificationChanged(account, _msgSender(), true);
  }

  function removeVerification(address account) public whenNotPaused onlyRole(VERIFIER_ROLE) {
    _verified[account] = false;
    emit AddressVerificationChanged(account, _msgSender(), false);
  }

  function isVerified(address account) public view virtual returns (bool) {
    return _verified[account];
  }

  function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
    require(_verified[to], "Account needs to be verified to accept minting");
    _mint(to, amount);
  }

  function burn(uint256 amount) public override onlyRole(BURNER_ROLE) {
    super.burn(amount);
  }

  function burnFrom(address account, uint256 amount) public override onlyRole(BURNER_ROLE) {
    super.burnFrom(account, amount);
  }

  function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
    if (hasRole(BURNER_ROLE, recipient)) {
      require(_verified[_msgSender()], "Sender Account needs to be verified to allow transfer to burn account");
    }
    _transfer(_msgSender(), recipient, amount);
    return true;
  }

  function _beforeTokenTransfer(address from, address to, uint256 amount) internal override whenNotPaused {
    super._beforeTokenTransfer(from, to, amount);
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}
