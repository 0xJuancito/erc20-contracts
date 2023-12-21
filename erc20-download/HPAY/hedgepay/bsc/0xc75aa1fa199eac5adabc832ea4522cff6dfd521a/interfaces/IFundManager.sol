// SPDX-License-Identifier: ISC

pragma solidity 0.8.9;

/**
    Fund contracts interface.
    The fund accepts ETH investments and generates USD rewards.

    The fund manages multiple asset pools and distributes capital to them. Each asset can receive capital and use 
    it to genearate USD returns which are sent back to the fund. Returns can be reinvested or made avaibale to
    the investors to claim.

    IMPORTANT: Funds manager can convert the ETH to other coins therfore the initial investment can lose it's value
*/
interface IFund {
    // Invest a BNB into the fund
    function invest() external payable;

    //INvest BNB into the fund
    function investBUSD(uint256 amount) external;

    // Claim BUSD rewards
    function claim(uint256 amount) external;

    // Claim BUSD rewards into other address
    function claimTo(uint256 amount, address _destination) external;

    // Add a new strategy
    function addStrategy(address strategyId) external;

    // Remove a strategy
    function removeStrategy(address strategyId, bool keepCapitalAsAssets, bool force) external;

    // Add a new client
    function addClient(address clientId) external;

    // Remove a client
    function removeClient(address clientId, address destinationAddress) external;

    // Get a strategy by index
    function getStrategy(uint256 index) external view  returns(address _address, bool exists, uint8 allocation);

    // Get a strategy by address
    function getStrategyByAddress(address _address) external view returns(uint256 index, bool exists, uint8 allocation);

    // Get total pending rewards value in BUSD
    function pendingRewards() external view returns (uint256);

    // Update fund allocation percentage
    function updateAllocation(address _strategyId, uint8 allocation) external;

    // Update client allocations
    function updateProfitAllocation(address _clientId, uint8 allocation) external;
}
