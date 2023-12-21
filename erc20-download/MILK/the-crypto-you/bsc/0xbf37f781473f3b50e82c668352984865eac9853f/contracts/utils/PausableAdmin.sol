// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/security/Pausable.sol";
import "./AdminRole.sol";

contract PausableAdmin is AdminRole, Pausable {
    function pause(bool _paused) external onlyOwner {
        _paused ? _pause() : _unpause();
    }
}
