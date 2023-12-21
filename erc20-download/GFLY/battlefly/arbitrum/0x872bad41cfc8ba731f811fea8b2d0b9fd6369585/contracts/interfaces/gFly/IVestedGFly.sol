// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IVestedGFly is IERC20 {
    struct VestingPosition {
        bool burnable;
        bool minted;
        address owner;
        uint256 startTime;
        uint256 lastBurnTime;
        uint256 employmentTimestamp;
        uint256 remainingAllocation;
        uint256 initialAllocation;
        uint256 initialUnlockable;
        uint256 burnt;
        uint256 vestedAtLastBurn;
        uint256 employeeBurnt;
    }

    function addVestingPosition(
        address owner,
        uint256 amount,
        bool burnable,
        uint256 initialUnlockable,
        uint256 employmentTimestamp
    ) external;

    function mint() external;

    function burn(uint256 vestingId, uint256 amount) external;

    function burnAll(uint256 vestingId) external;

    function transferVestingPosition(
        uint256 vestingId,
        uint256 amount,
        address newOwner
    ) external;

    function claimAllGFly() external;

    function claimGFly(uint256 vestingId) external;

    function totalVestedOf(address account) external view returns (uint256 total);

    function vestedOf(uint256 vestingId) external view returns (uint256);

    function totalClaimableOf(address account) external view returns (uint256 total);

    function claimableOf(uint256 vestingId) external view returns (uint256);

    function totalClaimedOf(address account) external view returns (uint256 total);

    function claimedOf(uint256 vestingId) external view returns (uint256);

    function totalBalance(address account) external view returns (uint256 total);

    function balanceOfVesting(uint256 vestingId) external view returns (uint256);

    function getVestingIdsOfAddress(address account) external view returns (uint256[] memory);

    function maxBurnable(uint256 vestingId) external view returns (uint256 burnable);

    function claimableOfAtTimestamp(uint256 vestingId, uint256 timestamp) external view returns (uint256);

    function unminted() external returns (uint256);

    event VestingPositionAdded(
        address indexed owner,
        uint256 indexed vestingId,
        uint256 amount,
        bool burnable,
        uint256 initialUnlockable,
        uint256 startTime
    );
    event Minted(address indexed owner, uint256 indexed vestingId, uint256 amount);
    event Burned(address indexed owner, uint256 indexed vestingId, uint256 amount);
    event GFlyClaimed(address indexed owner, uint256 indexed vestingId, uint256 amount);
    event VestingPositionTransfered(
        address indexed owner,
        uint256 indexed vestingId,
        address indexed newOwner,
        uint256 newVestingId,
        uint256 amount
    );
}
