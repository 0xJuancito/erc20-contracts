// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// Import OpenZeppelin contacts locally
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "./roleAccess.sol";

contract XToken is Pausable, RoleAccess, ERC20Burnable, ERC20Permit {
  using SafeMath for uint256;

  // variables
  uint256 internal _cap;
  mapping(address => bool) private frozen;

  constructor(
    string memory name,
    string memory symbol,
    uint256 cap_
  ) ERC20Permit(name) ERC20(name, symbol) {
    require(cap_ > 0, "ERC20: cap is 0");
    _cap = cap_;

    // owner has all roles
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(ADMIN_ROLE, _msgSender());
    _setupRole(MINTER_ROLE, _msgSender());
    _setupRole(BURNER_ROLE, _msgSender());
    _setupRole(BLACKLISTER_ROLE, _msgSender());
  }

  function cap() public view returns (uint256) {
    return _cap;
  }

  function setCap(uint256 cap_) external onlyAdmin returns (uint256) {
    require(cap_ > 0, "ERC20: cap is 0");
    require(
      cap_ > totalSupply(),
      "ERC20: new cap should be larger than total supply"
    );
    _cap = cap_;
    return _cap;
  }

  // only account with minter role can mint
  function mint(address account, uint256 amount)
    public
    onlyMinter
    whenNotPaused
  {
    require(ERC20.totalSupply() + amount <= cap(), "ERC20Capped: cap exceeded");
    _mint(account, amount);
  }

  function burn(uint256 amount) public override onlyBurner whenNotPaused {
    super.burn(amount);
  }

  function burnFrom(address account, uint256 amount)
    public
    override
    onlyBurner
    whenNotPaused
  {
    super.burnFrom(account, amount);
  }

  // when paused, both mint(), burn() and transfer() will revert
  function pause() external onlyAdmin {
    _pause();
  }

  function unpause() external onlyAdmin {
    _unpause();
  }

  // follow finCEN AML guidance
  function freeze(address account) external onlyBlacklister {
    frozen[account] = true;
  }

  function defrost(address account) external onlyBlacklister {
    frozen[account] = false;
  }

  // this hook runs before any mint or transfer function
  // it checks for pause and token cap
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal override {
    super._beforeTokenTransfer(from, to, amount);
    require(!paused(), "ERC20 Pausable: token transfer while paused");
    require(!frozen[from], "Source account frozen");
    require(!frozen[to], "Destination account frozen");
  }
}
