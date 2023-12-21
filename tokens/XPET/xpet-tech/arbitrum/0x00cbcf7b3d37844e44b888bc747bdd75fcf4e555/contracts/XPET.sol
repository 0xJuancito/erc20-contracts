// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract XPET is ERC20, AccessControl{
    // ROLES
    bytes32 public constant CONVERT_ROLE = keccak256("CONVERT_ROLE");

    constructor() ERC20("xPet.tech Token", "XPET"){
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CONVERT_ROLE, msg.sender);
        _mint(address(this), 300_000_000 * 10**18);
    }

    function withdraw(address user, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE)  {
        SafeERC20.safeTransfer(IERC20(address(this)), user, amount);
    }

    function convert(address user, uint256 amount) external onlyRole(CONVERT_ROLE)  {
        SafeERC20.safeTransfer(IERC20(address(this)), user, amount);
    }
}