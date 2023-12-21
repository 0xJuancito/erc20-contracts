// SPDX-License-Identifier: MIT
/*
    Created by DeNet
    
    Interface for ERC20Vesting 
*/

pragma solidity ^0.8.0;

interface IERC20Vesting {

    event Vested(address indexed to, uint256 value);

    function vestingToken() external view returns(address);

    function getAmountToWithdraw(address _user) external view returns(uint256);

    function withdraw() external;

    function withdrawFor(address _for) external;

    function approveVesting(address _to) external;

    function stopApproveVesting(address _to) external;
}