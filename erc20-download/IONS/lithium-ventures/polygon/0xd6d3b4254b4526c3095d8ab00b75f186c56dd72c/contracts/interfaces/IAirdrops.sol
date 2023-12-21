// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.4;

/**
 * @title IStaking.
 * @dev interface for staking
 * with params enum and functions.
 */
interface IAirdrops {
    function depositAssets(address, uint256, uint256) external payable;
    function setShareForMaticReward(address, uint256) external;
    function userPendingMatic(address user, uint amount) external;
    function pushIONAmount(uint _amount) external;
    function withdrawION(address user, uint _amount) external;
    function setShareForIONReward (address user,uint _prevLock, uint _amount) external; 
    function userPendingION(address user) external;
    function setTotalMatic(uint _amount) external;
    function distributionION(uint amount) external;
    function distributionMatic() external;
    function setMarketingWallet(address _address) external;
}
