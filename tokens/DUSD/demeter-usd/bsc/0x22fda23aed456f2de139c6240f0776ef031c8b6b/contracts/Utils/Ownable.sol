pragma solidity ^0.5.16;

import "./Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable is Context {
  address public owner;
  address public pendingOwner;

  event NewOwner(address indexed oldOwner, address indexed owner);
  event NewPendingOwner(address indexed pendingOwner);

  modifier onlyOwner() {
    require(msg.sender == owner, "Ownable: only owner");
    _;
  }

  modifier onlyPendingOwner() {
    require(msg.sender == pendingOwner, "Ownable: only pending owner");
    _;
  }

  /**
   * @dev Initializes the contract setting the deployer as the initial owner.
   */
  constructor () internal {
    owner = _msgSender();
    emit NewOwner(address(0), owner);
  }

  function setPendingOwner(address _pendingOwner) external onlyOwner {
    require(_pendingOwner != address(0), "Ownable: pending owner is 0");
    pendingOwner = _pendingOwner;

    emit NewPendingOwner(pendingOwner);
  }

  function acceptOwner() external onlyPendingOwner {
    address old = owner;
    owner = msg.sender;
    pendingOwner = address(0);

    emit NewOwner(old, owner);
  }
}
