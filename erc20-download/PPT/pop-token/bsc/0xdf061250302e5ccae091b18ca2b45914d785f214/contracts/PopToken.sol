// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

pragma solidity ^0.8.0;


contract PopToken is ERC20("Pop Token", "PPT"), Ownable, AccessControl, ERC20Permit("PPT") {
    using SafeERC20 for IERC20;

    // @notice Total number of tokens
    uint256 public maxSupply;

    constructor(uint256 _maxSupply){
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _mint(_msgSender(), _maxSupply);
        maxSupply = _maxSupply;
    }
}
