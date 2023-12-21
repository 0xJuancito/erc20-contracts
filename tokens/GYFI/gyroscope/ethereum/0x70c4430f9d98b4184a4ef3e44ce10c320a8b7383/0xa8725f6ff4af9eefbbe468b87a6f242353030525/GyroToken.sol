// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "ERC20Upgradeable.sol";

import "LogExpMath.sol";

contract GyroToken is ERC20Upgradeable {
    using LogExpMath for uint256;

    event GovernorChanged(address indexed oldGovernor, address indexed newGovernor);

    /// @notice the initial yearly inflation rate, 2%
    uint64 internal constant INITIAL_INFLATION_RATE = 2e16;

    uint256 internal constant ONE = 10**18;

    uint64 internal constant SECONDS_IN_YEAR = 365.25 days;

    /// @notice time of the first inflation
    /// inflation will start after the vesting schedule of 4 years
    uint64 internal constant INITIAL_INFLATION_DELAY = 4 * SECONDS_IN_YEAR;

    /// @notice address of the governance contract
    address public governor;

    /// @notice time of the latest inflation
    uint64 public latestInflationTimestamp;

    /// @notice the percentage of new tokens minted per year
    uint64 public inflationRate;

    modifier governanceOnly() {
        require(msg.sender == governor, "can only be called by governance");
        _;
    }

    function initialize(
        uint256 initialSupply,
        string calldata name,
        string calldata symbol
    ) external initializer {
        __ERC20_init(name, symbol);

        governor = msg.sender;
        inflationRate = INITIAL_INFLATION_RATE;
        latestInflationTimestamp = uint64(block.timestamp) + INITIAL_INFLATION_DELAY;

        _mint(msg.sender, initialSupply);
    }

    /// @notice mints new tokens to `account` according to the inflation schedule
    /// defined by `inflationRate` and `inflationInterval`
    /// Only governance is allowed to call this function
    function mint(address account) external virtual governanceOnly {
        require(
            block.timestamp >= latestInflationTimestamp,
            "cannot mint before the first inflation is scheduled"
        );
        require(account != address(0), "cannot mint to 0 address");

        uint256 timeEllapsedSinceLastInflation = block.timestamp - latestInflationTimestamp;
        uint256 exponent = (timeEllapsedSinceLastInflation * ONE) / SECONDS_IN_YEAR;
        uint256 currentSupply = totalSupply();
        uint256 newSupply = (currentSupply * (ONE + inflationRate).pow(exponent)) / ONE;
        uint256 amountToMint = newSupply - currentSupply;

        latestInflationTimestamp = uint64(block.timestamp);
        _mint(account, amountToMint);
    }

    /// @notice changes the governor to `newGovernor`
    /// This can only be called by the current governor
    function changeGovernor(address newGovernor) external governanceOnly {
        require(newGovernor != address(0), "governor cannot be the 0 address");
        require(newGovernor != msg.sender, "new governor cannot be the same as the current one");
        governor = newGovernor;
        emit GovernorChanged(msg.sender, newGovernor);
    }
}
