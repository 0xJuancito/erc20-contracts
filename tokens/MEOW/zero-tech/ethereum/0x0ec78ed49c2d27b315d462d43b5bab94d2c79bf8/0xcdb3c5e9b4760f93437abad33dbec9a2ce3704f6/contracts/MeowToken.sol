// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20SnapshotUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";


contract MeowToken is
  OwnableUpgradeable,
  ERC20Upgradeable,
  ERC20PausableUpgradeable,
  ERC20SnapshotUpgradeable {
  // Mapping which stores all addresses allowed to snapshot
  mapping(address => bool) authorizedToSnapshot;

  /**
   * @dev We add this to disallow initializing the implementation contract
   * when deployed as recommended by OpenZeppelin
   * https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable#initializing_the_implementation_contract
   */
  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializer for the proxy with token name, symbol and amount
   * @param name_ is the Token Name
   * @param symbol_ is the Token Symbol
   */
  function initialize(string memory name_, string memory symbol_)
  public
  initializer
  {
    __Ownable_init();
    __ERC20_init(name_, symbol_);
    __ERC20Snapshot_init();
    __ERC20Pausable_init();
  }

  /**
   * @dev Retrieves the balance of `account` at the time `snapshotId` was created.
   * @return uint 256
   * @notice  implementation disabled because snapshot not used anymore, only to preserve state variables
   */
  function balanceOfAt(address, uint256) public view virtual override returns (uint256) {
    revert("Snapshot functionality removed");
  }

  /**
   * @dev Retrieves the total supply at the time `snapshotId` was created.
   * @return uint256
   * @notice  implementation disabled because snapshot not used anymore, only to preserve state variables
   */
  function totalSupplyAt(uint256) public view virtual override returns(uint256) {
      revert("Snapshot functionality removed");
  }

  /**
   * Utility function to transfer tokens to many addresses at once.
   * @param recipients The addresses to send tokens to
   * @param amount The amount of tokens to send
   * @return Boolean if the transfer was a success
   */
  function transferBulk(address[] calldata recipients, uint256 amount)
  external
  returns (bool)
  {
    require(amount > 0, "MeowToken: amount must be greater than 0");
    address sender = _msgSender();
    uint256 length = recipients.length;

    for (uint256 i; i < length;) {
      address recipient = recipients[i];
      _transfer(sender, recipient, amount);
      unchecked {++i;}
    }
    return true;
  }

  /**
   * Utility function to transfer tokens to many addresses at once.
   * @param sender The address to send the tokens from
   * @param recipients The addresses to send tokens to
   * @param amount The amount of tokens to send
   * @return Boolean if the transfer was a success
   */
  function transferFromBulk(
    address sender,
    address[] calldata recipients,
    uint256 amount
  ) external returns (bool) {
    require(amount > 0, "MeowToken: amount must be greater than 0");

    uint256 length = recipients.length;
    for (uint256 i; i < length;) {
      address recipient = recipients[i];
      transferFrom(sender, recipient, amount);
      unchecked {++i;}
    }
    return true;
  }


  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  )
  internal
  virtual
  override(
  ERC20PausableUpgradeable,
  ERC20SnapshotUpgradeable,
  ERC20Upgradeable
  )
  {}

  function _afterTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal virtual override {
    if (to == address(this)) { //token were sent to this address, we need to burn them
      _burn (to, amount); // burn from the contract itself.
    }
  }
}
