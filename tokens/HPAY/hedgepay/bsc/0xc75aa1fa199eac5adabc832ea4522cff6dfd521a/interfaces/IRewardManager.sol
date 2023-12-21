// SPDX-License-Identifier: ISC

pragma solidity 0.8.9;

interface IRewardManager  {
    // Called by the token contract whenever a transfer happends
    function notifyBalanceUpdate(address _address, uint256 prevBalance) external;

    // Returns the unclaimed reward value of a given address
    function unclaimedRewardValue(address _address) external view returns (uint256);

    function fee(address _address) external view returns (uint256);
}
