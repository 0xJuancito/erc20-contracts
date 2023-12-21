pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NemesisToken is ERC20, Ownable {

  constructor(string memory name_, string memory symbol_, uint256 _amount, address newOwner) Ownable() ERC20(name_, symbol_) {
    _mint(newOwner, _amount);
    _transferOwnership(newOwner);
  }
}