// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.4;

interface ISuperCharge {
    function userDetails(address) external returns (uint256, bool);

    function superChargeRewards(uint256)
        external
        returns (
            uint256,
            uint256,
            bool
        );

    function superChargeCount() external returns (uint256);

    function setUserStateWithDeposit(address user) external;

    function setUserStateWithWithdrawal(address user) external;

    function canClaim(address, uint256) external returns (bool);

    function claimSuperCharge(address user) external;

    function startEpoch() external;

    function endEpoch(uint256 amount) external;

    function userRewards(address user, uint256 stakedAmount)
        external
        view
        returns (uint256 amount, uint256 end);

    function setION(address _ION) external;

    function setAdmin(address _admin) external;
}
