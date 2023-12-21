// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../core/Access.sol";

contract WINR is ERC20, Access {
  /*==================================================== Events =============================================================*/
  event Mint(address indexed to, uint256 amount, uint256 remainingSupply);
  event Burn(address indexed from, uint256 amount);
  /*==================================================== State Variables ====================================================*/
  uint256 public MAX_SUPPLY;

  /*======================================================= Constructor =====================================================*/
  constructor(
    string memory _name,
    string memory _symbol,
    address _admin,
    uint256 _maxSupply
  ) ERC20(_name, _symbol) Access(_admin) {
    MAX_SUPPLY = _maxSupply;
  }

  /*======================================================= Functions ======================================================*/
  /**
   *
   * @param account  mint to address
   * @param amount  mint amount
   * @dev mint function will not mint if it causes the total supply to exceed MAX_SUPPLY
   * @dev returns minted amount and remaining from MAX_SUPPLY
   */
  function mint(
    address account,
    uint256 amount
  ) external onlyRole(MINTER_ROLE) returns (uint256, uint256) {
    bool canMint = (totalSupply() + amount <= MAX_SUPPLY);
    uint256 minted = canMint ? amount : 0;
    if (canMint) {
      _mint(account, amount);
    }

    uint256 remainingSupply = MAX_SUPPLY - totalSupply();
    emit Mint(account, minted, remainingSupply);

    return (minted, remainingSupply);
  }

  /**
   *
   * @param amount amount to burn
   * @dev burns the given amount of tokens from the caller
   */
  function burn(uint256 amount) external {
    _burn(msg.sender, amount);
    MAX_SUPPLY -= amount;
    emit Burn(msg.sender, amount);
  }
}
