// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title SonorusVestingDistributor
 * @author SonorusDeveloper
 * @notice Distributes vested SNS tokens to a beneficiary based on weekly cliff.
 */
contract SonorusVestingDistributor is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    IERC20 public snsToken;

    address public beneficiary;

    uint256 public vestingStartTime;
    uint256 public vestingEndTime;

    uint256 public totalAllocatedAmount;
    uint256 public initialVestedAmount;
    uint256 public vestingAmountPerWeek;
    uint256 public totalClaimedAmount;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _snsToken,
        uint256 _totalAllocatedAmount,
        uint256 _initialVestRate,
        uint256 _lockTime,
        uint256 _vestingDuration,
        address _beneficiary
    ) {
        require(
            _vestingDuration % 7 days == 0,
            "Vesting duration must be multiple of 7 days"
        );
        require(
            _initialVestRate <= 100,
            "Initial vest rate must be less than or equal to 100"
        );
        require(
            _beneficiary != address(0),
            "Beneficiary cannot be zero address"
        );

        snsToken = IERC20(_snsToken);
        totalAllocatedAmount = _totalAllocatedAmount;
        vestingStartTime = _lockTime + block.timestamp;
        vestingEndTime = vestingStartTime + _vestingDuration;
        beneficiary = _beneficiary;
        initialVestedAmount = (totalAllocatedAmount * _initialVestRate) / 100;
        vestingAmountPerWeek =
            (_totalAllocatedAmount - initialVestedAmount) /
            (_vestingDuration / 7 days);
    }

    /* ========== VIEWS ========== */

    /**
     * @dev Returns the amount of vested tokens at the current block timestamp.
     *      Vesting is based on weekly periods, with the initial amount vesting.
     * @return uint256
     */
    function vestedAmount() public view returns (uint256) {
        if (block.timestamp < vestingStartTime) {
            return initialVestedAmount;
        } else if (block.timestamp >= vestingEndTime) {
            return totalAllocatedAmount;
        } else {
            // solidity automatically rounds down
            uint256 elapsedWeeks = (block.timestamp - vestingStartTime) /
                7 days;
            return initialVestedAmount + vestingAmountPerWeek * elapsedWeeks;
        }
    }

    /**
     * @dev Returns the amount of claimable tokens at the current block timestamp.
     * @return uint256
     */
    function claimableAmount() public view returns (uint256) {
        return vestedAmount() - totalClaimedAmount;
    }

    /* ========== RESTRICTED MUTATIVE FUNCTIONS ========== */

    /**
     * @dev Claim vested tokens. Only callable by the beneficiary.
     */
    function claim() external nonReentrant {
        require(msg.sender == beneficiary, "Only beneficiary");
        uint256 amount = claimableAmount();
        require(amount > 0, "Nothing to claim");
        totalClaimedAmount += amount;
        snsToken.safeTransfer(beneficiary, amount);
        emit Claimed(beneficiary, amount);
    }

    function setRecipient(address recipient_) public {
        require(msg.sender == beneficiary, "Only beneficiary");
        beneficiary = recipient_;
    }

    /* ========== EVENTS ========== */
    event Claimed(address indexed beneficiary, uint256 amount);
}
