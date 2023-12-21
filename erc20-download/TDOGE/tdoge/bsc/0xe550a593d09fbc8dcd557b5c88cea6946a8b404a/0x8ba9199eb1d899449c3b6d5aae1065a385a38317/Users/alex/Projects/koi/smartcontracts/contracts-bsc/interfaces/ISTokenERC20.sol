// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
import "../../3rdParty/@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface ISTokenERC20 {
    function linearLockedBalanceOf(address account) external view returns (uint256);
    function getFreeToTransferAmount(address account) external view returns (uint256);

    function totalSupplyReleaseByTimeLock() external view returns (uint256);
    function totalReleasedSupplyReleaseByTimeLock() external view returns (uint256);
    function getTotalRemainingSupplyLocked() external view returns (uint256);

    
    function transferLockedFrom(address from,address to,uint256 amount) external  returns(uint[] memory,uint256[] memory);   
    function approveLocked(address spender,uint256 amount) external returns(bool);
    function allowanceLocked(address owner, address spender) external view returns (uint256);
    
}