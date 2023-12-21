// SPDX-License-Identifier: ISC

pragma solidity 0.8.9;

/**
    InvestmentStrategy contracts interface.
    Capital can be added to an investment strategy in the form of BNB

    The contract uses the capital to genrate returns.
*/
interface IInvestmentStrategy {
    // Add capital to the investment strategy
    function addCapital() external payable;

   // Add capital to the investment strategy
    function addBusdCapital(uint256 amount) external;

    // Add capital to the investment strategy
    function addAssetCapital(uint256 amount) external;

    // Remove capital from the strategy
    function withdrawCapital(uint256 amount, address receiver) external;

    // Remove capital from the strategy
    function withdrawCapitalAsAssets(uint256 amount, address receiver) external;

    // Collects the rewards genrated while staking
    function collectProfit(address _receiver) external returns(uint256 profit);

    // Returns the unrealized rewards genrated while staking
    function pendingProfit() external view returns (uint256);

    // Reinvest profits into this strategy
    function rollProfit() external;

     // Return asset pool value
    function assetPoolValue() external view returns (uint256 assetAmount, uint256 busdAmount);

}
