/**
 * @title TokenRecover
 * @author Vittorio Minacori (https://github.com/vittominacori)
 * @dev Allow to recover any ERC20 sent into the contract for error
 */
pragma solidity ^0.6.12;

import '@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol';
import '@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol';

contract TokenRecover is Ownable {

  /**
   * @dev Remember that only owner can call so be careful when use on contracts generated from other contracts.
   * @param tokenAddress The token contract address
   * @param tokenAmount Number of tokens to be sent
   */
  function recoverBEP20(
    address tokenAddress,
    uint256 tokenAmount
  )
    public
    onlyOwner
  {
    IBEP20(tokenAddress).transfer(owner(), tokenAmount);
  }
}