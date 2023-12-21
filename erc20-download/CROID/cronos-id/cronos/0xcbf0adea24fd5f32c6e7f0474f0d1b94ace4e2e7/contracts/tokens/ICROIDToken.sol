// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";

interface ICROIDToken is IERC20, IERC20Metadata, IERC20Permit { 

    function getDeploymentStartTime() external view returns (uint256);
    
    function burn(uint256 amount) external;
}