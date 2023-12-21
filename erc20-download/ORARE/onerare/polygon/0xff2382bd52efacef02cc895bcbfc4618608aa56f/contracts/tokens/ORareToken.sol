// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../libraries/ERC20Permit.sol";
import "../access/Ownable.sol";

/**
 * @title ORare Token
 * @dev ORare ERC20 Token
 */
contract ORareToken is ERC20Permit, Ownable {
    using SafeERC20 for IERC20;

    uint256 public constant MAX_CAP = 100 * (10**6) * (10**18); // 100 million

    event RecoverToken(IERC20 indexed token, address indexed destination, uint256 indexed amount);

    constructor(address owner_) ERC20("One Rare Token", "ORARE") {
        initOwner(owner_);
        _mint(owner_, MAX_CAP);
    }

    /**
     * @notice Function to recover funds
     * Owner is assumed to be ORARE trusted party for helping users,
     * to recover any tokens sent to this contract by mistake
     */
    function recoverToken(
        IERC20 token,
        address destination,
        uint256 amount
    ) external onlyOwner {
        token.safeTransfer(destination, amount);
        emit RecoverToken(token, destination, amount);
    }
}
