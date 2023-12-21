// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

interface IVentureCapital {
    function addTotalSharesOfAndRebalance(address staker, uint256 shares) external;

    function subTotalSharesOfAndRebalance(address staker, uint256 shares) external;

    function withdrawDivTokensFromToExternal(address from, address payable to) external;

    function withdrawDivTokensToAccelerator(
        address from,
        address tokenAddress,
        address payable acceleratorAddress
    ) external;

    function transferSharesAndRebalance(
        address from,
        address to,
        uint256 shares
    ) external;

    function transferSharesAndRebalance(
        address from,
        address to,
        uint256 oldShares,
        uint256 newShares
    ) external;

    function updateTokenPricePerShare(address tokenAddress, uint256 amountBought) external payable;

    function updateTokenPricePerShareAxn(uint256 amountBought) external;

    function addDivToken(address tokenAddress) external;

    function getTokenInterestEarned(address accountAddress, address tokenAddress)
        external
        view
        returns (uint256);
}
