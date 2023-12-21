/* SPDX-License-Identifier: MIT */
pragma solidity 0.8.7;

import ".././access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../libs/ERC20Permit.sol";

contract DeltaHubCommunity is ERC20Permit, Ownable {
    using SafeERC20 for IERC20;

    uint256 public constant MAX_CAP = 10 * (10**6) * (10**18); // 10 million

    event RecoverToken(IERC20 indexed token, address indexed destination, uint256 indexed amount);

    constructor(address owner) ERC20("DeltaHub Community", "DHC") {
        initOwner(owner);
        _mint(owner, MAX_CAP);
    }

    /**
     * @notice Function to recover funds
     * Owner is assumed to be DHC trusted party for helping users,
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
