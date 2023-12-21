pragma solidity ^0.6.6;

import "./ERC20.sol";
import "./Pausable.sol";
import "./PausableUser.sol";

/**
 * @title Pausable token
 * @dev ERC20 modified with pausable transfers.
 **/
contract ERC20Pausable is ERC20, Pausable, PausableUser {

  function transfer(
    address to,
    uint256 value
  )
    public
    override
    whenNotPaused
    whenNotPausedUser(msg.sender)
    returns (bool)
  {
    return super.transfer(to, value);
  }

  function transferFrom(
    address from,
    address to,
    uint256 value
  )
    public
    override
    whenNotPaused
    whenNotPausedUser(from)
    returns (bool)
  {
    return super.transferFrom(from, to, value);
  }

  function approve(
    address spender,
    uint256 value
  )
    public
    override
    whenNotPaused
    whenNotPausedUser(msg.sender)
    returns (bool)
  {
    return super.approve(spender, value);
  }

  function increaseAllowance(
    address spender,
    uint addedValue
  )
    public
    override
    whenNotPaused
    whenNotPausedUser(msg.sender)
    returns (bool success)
  {
    return super.increaseAllowance(spender, addedValue);
  }

  function decreaseAllowance(
    address spender,
    uint subtractedValue
  )
    public
    override
    whenNotPaused
    whenNotPausedUser(msg.sender)
    returns (bool success)
  {
    return super.decreaseAllowance(spender, subtractedValue);
  }
}
