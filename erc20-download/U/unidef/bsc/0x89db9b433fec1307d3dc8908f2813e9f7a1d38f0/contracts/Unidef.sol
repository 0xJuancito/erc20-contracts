// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @dev OGT fungible token.
 */
contract Unidef is ERC20, Ownable {
  using SafeERC20 for IERC20;

  event TransferExternalERC20(address indexed erc20Address, address to, uint256 value);

  /**
   * @dev Initializes the contract.
   */
  constructor(address _owner) ERC20("Unidef", "U") {
    _mint(_owner, 990_000_000_000 * 10**decimals());
    _transferOwnership(_owner);
  }

  /**
   * @dev Gets balance of third party ERC20 token
   *
   */
  function getBalanceOfExternalERC20(address _erc20Address) external view returns (uint256) {
    return IERC20(_erc20Address).balanceOf(address(this));
  }

  /**
   * @dev Transfer third party ERC20 tokens.
   *
   * Requirements:
   * - onlyOwner can call this function.
   * - Can't transfer this contract token.
   */
  function transferExternalERC20(
    address _erc20Address,
    address _recipient,
    uint256 _amount
  ) external onlyOwner {
    require(_erc20Address != address(this), "Unidef: cannot transfer this contract's tokens");
    IERC20(_erc20Address).safeTransfer(_recipient, _amount);
    emit TransferExternalERC20(_erc20Address, _recipient, _amount);
  }
}
