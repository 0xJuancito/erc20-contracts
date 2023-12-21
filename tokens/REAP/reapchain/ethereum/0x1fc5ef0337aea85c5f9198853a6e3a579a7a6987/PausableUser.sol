pragma solidity ^0.6.6;

import "./PauserRole.sol";

/**
 * @title PausableUser
 * @dev Base contract which allows children to implement an emergency stop mechanism.
 */
contract PausableUser is PauserRole {
  event PausedUser(address _user);
  event UnpausedUser(address _user);
  
  mapping (address => bool) private _pausedUser;

  /**
   * @return true if the address is paused, false otherwise.
   */
  function pausedUser(address _user) public view returns(bool) {
    return _pausedUser[_user];
  }

  /**
   * @dev Modifier to make a function callable only when the address is not paused.
   */
  modifier whenNotPausedUser(address _user) {
    require(!_pausedUser[_user]);
    _;
  }

  /**
   * @dev Modifier to make a function callable only when the address is paused.
   */
  modifier whenPausedUser(address _user) {
    require(_pausedUser[_user]);
    _;
  }

  /**
   * @dev called by the owner to pause user, triggers stopped state
   */
  function pauseUser(address _user) public onlyPauser whenNotPausedUser(_user) {
    _pausedUser[_user] = true;
    emit PausedUser(_user);
  }

  /**
   * @dev called by the owner to unpause user, returns to normal state
   */
  function unpauseUser(address _user) public onlyPauser whenPausedUser(_user) {
    _pausedUser[_user] = false;
    emit UnpausedUser(_user);
  }
}
