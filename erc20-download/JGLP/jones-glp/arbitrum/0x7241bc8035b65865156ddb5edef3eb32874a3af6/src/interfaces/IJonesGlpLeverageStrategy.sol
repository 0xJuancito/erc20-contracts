// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IJonesGlpLeverageStrategy {
    /**
     * @notice React to a GLP deposit, borrow GLO from Vault & relabance
     * @param _amount Amount of GLP deposited
     */
    function onGlpDeposit(uint256 _amount) external;

    /**
     * @notice React to a GLP redeem, pay stable debt if is need and transfer GLP to the user
     * @param _amount Amount that the user is attempting to redeem
     * @return Amount of GLP to redeem
     */
    function onGlpRedeem(uint256 _amount) external returns (uint256);

    /**
     * @notice React to a Stable deposit, relabance if is needed
     */
    function onStableDeposit() external;

    /**
     * @notice Redeem GLP for stables
     * @param _amount Amount of stables to reduce from debt
     * @param _amountAfterRetention Amount of stables getting from redeem GLP
     * @return Amount of stables getting from redeem GLP
     */
    function onStableRedeem(uint256 _amount, uint256 _amountAfterRetention) external returns (uint256);

    /**
     * @notice Claim GLP rewards from GMX and split them
     */
    function claimGlpRewards() external;

    /**
     * @notice Return the current utilization of stable Vault
     * @dev Precision is based on 1e12 as 100% percent
     * @return The % of utilization
     */
    function utilization() external view returns (uint256);

    /**
     * @notice Return the current GLP leverage position
     * @dev Precision is based on 1e12 as 1x leverage
     * @return Leverage position
     */
    function leverage() external view returns (uint256);

    /**
     * @notice Return the amount of GLP that represent 1x of leverage
     * @return Amount of GLP
     */
    function getUnderlyingGlp() external view returns (uint256);

    /**
     * @notice Return the stable debt
     * @return Amount of stable debt
     */
    function stableDebt() external view returns (uint256);

    /**
     * @notice Get the stable value of sell _amount of GLP
     * @param _glpAmount Amount of GLP
     * @return Stables getting from _glpAmount of GLP
     */
    function getStableGlpValue(uint256 _glpAmount) external view returns (uint256);

    /**
     * @notice Get the simulated GLP amount minted with USDC
     * @param _stableAmount Amount of USDC
     * @return Stables Amount of simulated GLP
     */
    function buyGlpStableSimulation(uint256 _stableAmount) external view returns (uint256);

    /**
     * @notice Get the required USDC amount to mint _glpAmount of GLP
     * @param _glpAmount Amount of GLP to be minted
     * @return Amount of stables required to mint _glpAmount of GLP
     */
    function getRequiredStableAmount(uint256 _glpAmount) external view returns (uint256);

    /**
     * @notice Get the simulated GLP amount required to redeem _stableAmount of USDC
     * @param _stableAmount Amount of USDC
     * @return Stables Amount of simulated GLP amount required to redeem _stableAmount of USDC
     */
    function getRequiredGlpAmount(uint256 _stableAmount) external view returns (uint256);

    /**
     * @notice Get the simulated GLP mint retention on a glp deposit
     * @param _glpAmount Amount of GLP deposited
     * @return GLP Amount of retention
     */
    function glpMintIncentive(uint256 _glpAmount) external view returns (uint256);

    /**
     * @notice Get GMX incentive to redeem stables
     * @param _stableAmount Amount of stables
     * @return GMX retention to redeem stables
     */
    function getRedeemStableGMXIncentive(uint256 _stableAmount) external view returns (uint256);

    /**
     * @notice Return max leverage configuration
     * @return Max leverage
     */
    function getMaxLeverage() external view returns (uint256);

    /**
     * @notice Return min leverage configuration
     * @return Min leverage
     */
    function getMinLeverage() external view returns (uint256);

    /**
     * @notice Return target leverage configuration
     * @return Target leverage
     */
    function getTargetLeverage() external view returns (uint256);

    /**
     * @notice Return the amount of GLP to reach the GMX cap for USDC
     * @return Cap Difference
     */
    function getGMXCapDifference() external view returns (uint256);

    /**
     * @notice Get the simulated GLP redeem retention on a glp redeem
     * @param _glpAmount Amount of GLP redeemed
     * @return GLP Amount of retention
     */
    function glpRedeemRetention(uint256 _glpAmount) external view returns (uint256);

    event Rebalance(
        uint256 _glpDebt, uint256 indexed _currentLeverage, uint256 indexed _newLeverage, address indexed _sender
    );
    event GetUnderlyingGlp(uint256 _amount);
    event SetLeverageConfig(uint256 _target, uint256 _min, uint256 _max);
    event ClaimGlpRewards(
        address indexed _origin,
        address indexed _sender,
        uint256 _rewards,
        uint256 _timestamp,
        uint256 _leverage,
        uint256 _glpBalance,
        uint256 _underlyingGlp,
        uint256 _glpShares,
        uint256 _stableDebt,
        uint256 _stableShares
    );

    event Liquidate(uint256 indexed _stablesReceived);
    event BorrowGlp(uint256 indexed _amount);
    event BorrowStable(uint256 indexed _amount);
    event RepayStable(uint256 indexed _amount);
    event RepayGlp(uint256 indexed _amount);
    event EmergencyWithdraw(address indexed _to, uint256 indexed _amount);
    event UpdateStableAddress(address _oldStableAddress, address _newStableAddress);
    event UpdateGlpAddress(address _oldGlpAddress, address _newGlpAddress);
    event Leverage(uint256 _glpDeposited, uint256 _glpMinted);
    event LeverageUp(uint256 _stableDebt, uint256 _oldLeverage, uint256 _currentLeverage);
    event LeverageDown(uint256 _stableDebt, uint256 _oldLeverage, uint256 _currentLeverage);
    event Deleverage(uint256 _glpAmount, uint256 _glpRedeemed);

    error ZeroAddressError();
    error InvalidLeverageConfig();
    error InvalidSlippage();
    error ReachedSlippageTolerance();
    error OverLeveraged();
    error UnderLeveraged();
    error NotEnoughUnderlyingGlp();
}
