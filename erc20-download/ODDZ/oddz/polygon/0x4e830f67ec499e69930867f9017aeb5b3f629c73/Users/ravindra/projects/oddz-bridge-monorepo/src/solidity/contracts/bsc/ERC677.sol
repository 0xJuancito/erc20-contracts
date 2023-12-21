// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../libs/Misc.sol";

contract ERC677 is ERC20, Ownable {
  bytes4 internal constant START_UNLOCK_FUNCTION = 0xde207035; // requestUnlock(address,uint256)

  constructor(
    string memory name, 
    string memory symbol
  ) ERC20(name, symbol) {
  }

  /**
   * Creates `amount` tokens and assigns them to `account`, increasing
   * @param to the address that will receive the newly minted tokens
   * @param amount the amount of tokens that will be minted
   */
  function mint(
    address to, 
    uint256 amount
  ) onlyOwner public virtual {
    _mint(to, amount);
  }

  /**
   * Burns the given amount of tokens
   * @param amount the amount of tokens that will be burnt
   */
  function burn(
    uint256 amount
  ) onlyOwner public {
    _burn(msg.sender, amount);
  }

  /**
   * This hook function is called within the transfer function of the ERC20. Since we don't want to execute
   * any logic, we keep this function empty
   */
  function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
    // Do nothing
  }

  /**
   * Executes and erc20 transfer and the calls the designated contract address using the given abi 
   * call data
   * @param to the contract address that will receive the tokens, as well as, will be executed
   * @param amount the amount of tokens that will be sent
   */
  function transferAndCall(address to, uint256 amount, bytes memory) external virtual returns (bool) {
    require(transfer(to, amount), "ERC677:transferAndCall error");

    if (Misc.isContract(to)) {
      (bool success,) = to.call(abi.encodeWithSelector(START_UNLOCK_FUNCTION, msg.sender, amount));
      
      require(
        success,
        "ERC677:transferAndCall error remote returned false"
      );
    }

    return true;
  }
}
