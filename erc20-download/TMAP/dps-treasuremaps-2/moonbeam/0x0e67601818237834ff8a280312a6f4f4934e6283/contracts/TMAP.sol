//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TMAP is ERC20, AccessControl {
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE");

    constructor() ERC20("TreasureMaps", "TMAP") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(GOVERNANCE_ROLE, msg.sender);
    }

    function mint(address _to, uint256 _amount) external onlyRole(GOVERNANCE_ROLE) {
        _mint(_to, _amount);
    }

    function burn(address _to, uint256 _amount) external onlyRole(GOVERNANCE_ROLE) {
        _burn(_to, _amount);
    }
}
