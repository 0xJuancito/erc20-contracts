// SPDX-License-Identifier: MIT

pragma solidity 0.8.1;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ERC20Permit.sol";

/**
 * @title Polysports Token
 * @dev Polysports ERC20 Token
 */
contract PolysportsToken is ERC20Permit {
    uint256 public constant MAX_CAP = 1000 * (10**6) * (10**18); // 1000 million = 1 billion

    address public governance;

    event GovernanceChanged(address indexed previousGovernance, address indexed newGovernance);
    event RecoverToken(address indexed token, address indexed destination, uint256 indexed amount);

    modifier onlyGovernance() {
        require(msg.sender == governance, "!governance");
        _;
    }

    constructor() ERC20("PolysportsToken", "PS1") {
        governance = msg.sender;
        _mint(governance, MAX_CAP);
    }

    /**
     * @notice Function to set governance contract
     * Owner is assumed to be governance
     * @param _governance Address of governance contract
     */
    function setGovernance(address _governance) public onlyGovernance {
        require(_governance != address(0), "Invalid address");
        governance = _governance;
        emit GovernanceChanged(msg.sender, _governance);
    }

    /**
     * @notice Function to recover funds
     * Owner is assumed to be governance or Polysports trusted party for helping users
     * @param token Address of token to be rescued
     * @param destination User address
     * @param amount Amount of tokens
     */
    function recoverToken(
        address token,
        address destination,
        uint256 amount
    ) external onlyGovernance {
        require(token != destination, "Invalid address");
        require(destination != address(0), "Invalid address");
        require(IERC20(token).transfer(destination, amount), "Retrieve failed");
        emit RecoverToken(token, destination, amount);
    }

    /**
     * @dev Burns a specific amount of tokens.
     * @param value The amount of token to be burned.
     */
    function burn(uint256 value) public {
        _burn(msg.sender, value);
    }

}