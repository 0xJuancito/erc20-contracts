// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IveLNDX.sol";
import "./interfaces/ILNDX.sol";

contract LNDX is ILNDX, ERC20, Ownable, AccessControl {
    enum StakePeriods {
        MONTHS_3,
        MONTHS_12,
        MONTHS_48
    }

    struct Grant {
        uint256 createdTime;
        uint256 startTime;
        uint256 amount;
        uint256 vestingDuration;
        uint256 daysClaimed;
        uint256 totalClaimed;
        address recipient;
        uint256 veLndxClaimed;
        uint256 remainingVeLndx;
        uint256 remainingRewards;
        uint256 remainingFee;
    }

    struct Stake {
        address staker;
        uint256 amount;
        uint256 startTime;
        uint256 endTime;
        uint256 veLndxClaimed;
        bool unstaked;
    }

    struct RewardVesting {
        uint256 amountVested;
        uint256 vestingStartedAt;
        uint256 lastVestedAt;
        uint256 daysClaimed;
    }

    bytes32 public constant FEE_DISTRIBUTOR = keccak256("FEE_DISTRIBUTOR");

    uint256 public constant MAX_MINTABLE_AMOUNT = 80000000000000;
    uint256 public constant MAX_REWARD_AMOUNT = 15600000000000;
    uint256 public totalGranted = 0;

    address usdc;
    address veLNDX;
   
    mapping(StakePeriods => uint8) public coefficients;

    mapping(uint256 => Stake) public stakes;
    uint256 public stakesCount;

    mapping(address => Grant) public grants;

    mapping(address => uint256) public feePerGrant;
    mapping(address => uint256) public rewardsPerGrant;

    mapping(uint256 => uint256) public feePerStake;
    mapping(uint256 => uint256) public rewardsPerStake;

    uint256 public feeSharesPerToken;
    uint256 public feeNotDistributed;

    uint256 public rewardSharesPerToken;
    uint256 public rewardNotDistributed;

    uint256 public totalStaked;
    uint256 public totalLocked;

    mapping (address => uint256[2]) public stakerClaimed;
    mapping (address => uint256) public staked;

    uint16 public rewardVestingDuration; // reward vesting duration in days;

    RewardVesting public rewardVested;

    event GrantAdded(address recipient, uint256 amount, uint256 cliffEndAt, uint256 vestingEndAt);
    event GrantTokensClaimed(address recipient, uint256 amountClaimed);

    event Staked(address user, uint256 amount, uint256 stakeId, uint256 endAt);
    event Unstaked(address user, uint256 amount, uint256 stakeId);

    constructor(
        address _usdc,
        address _veLNDX,
        uint16 _rewardVestingDuration
    ) ERC20("LandX Governance Token", "LNDX") {
        require(_usdc != address(0), "zero address is not allowed");
        require(_veLNDX != address(0), "zero address is not allowed");
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        usdc = _usdc;
        veLNDX = _veLNDX;
        coefficients[StakePeriods.MONTHS_3] = 25;
        coefficients[StakePeriods.MONTHS_12] = 50;
        coefficients[StakePeriods.MONTHS_48] = 100;

        if (_rewardVestingDuration == 0) {
            rewardVestingDuration = 1825; // 5 years = 1825 days
        } else {
            rewardVestingDuration = _rewardVestingDuration;
        }
    }

    /**
        LNDX Vesting logic
    */
   function grantLNDX(
        address recipient,
        uint256 amount,
        uint256 cliffInMonths,
        uint256 vestingDurationInMonths
    ) external onlyOwner {
        _rewardsToDistribute();
        require(
            (totalGranted + amount) <= (MAX_MINTABLE_AMOUNT - MAX_REWARD_AMOUNT),
            "Mint limit amount exceeded"
        );
        if (cliffInMonths == 0 && vestingDurationInMonths == 0) {
            _mint(recipient, amount);
             totalGranted += amount;
            return;
        }

        require(grants[recipient].amount == 0, "grant already exists");
        require(cliffInMonths <= 60, "cliff greater than 5 year");
        require(vestingDurationInMonths <= 60, "duration greater than 5 years");
        uint256 totalPeriod = cliffInMonths + vestingDurationInMonths;

        uint8 coefficient;
        if (totalPeriod >= 48) {
            coefficient = coefficients[StakePeriods.MONTHS_48];
        }
        else if (totalPeriod >= 12) {
            coefficient = coefficients[StakePeriods.MONTHS_12];
        } else {
            coefficient = coefficients[StakePeriods.MONTHS_3];
        }

        _mint(address(this), amount);
        totalGranted += amount;
        totalLocked += amount;

        uint256 veLNDXAmount = (amount * coefficient) / 100;

        IveLNDX(veLNDX).mint(recipient, veLNDXAmount);

        rewardsPerGrant[recipient] = rewardSharesPerToken * veLNDXAmount / 1e6;
        feePerGrant[recipient] = feeSharesPerToken * veLNDXAmount / 1e6;

        uint256 startTime = block.timestamp +
            (30 days * uint256(cliffInMonths));

        Grant memory grant = Grant({
            createdTime: block.timestamp,
            startTime: startTime,
            amount: amount,
            vestingDuration: vestingDurationInMonths * 30,
            daysClaimed: 0,
            totalClaimed: 0,
            recipient: recipient,
            veLndxClaimed: veLNDXAmount,
            remainingVeLndx: veLNDXAmount,
            remainingRewards: 0,
            remainingFee: 0
        });

        grants[recipient] = grant;
        emit GrantAdded(recipient, amount, startTime, startTime + vestingDurationInMonths * 30 * 1 days);
    }

    function claimVestedTokens() external {
        uint256 daysVested;
        uint256 amountVested;
        (daysVested, amountVested) = calculateGrantClaim(msg.sender);
        require(amountVested > 0, "wait one day or vested is 0");
        _rewardsToDistribute();
        Grant storage grant = grants[msg.sender];
        grant.daysClaimed += daysVested;
        grant.totalClaimed += amountVested;
        uint256 veLNDXAmount = (amountVested * grant.veLndxClaimed) /
            grant.amount;

         if (grant.totalClaimed == grant.amount) {
            veLNDXAmount = grant.remainingVeLndx;
         }

        IveLNDX(veLNDX).burn(msg.sender, veLNDXAmount);

        totalLocked -= amountVested;
        uint256 totalFee = computeGrantFee(msg.sender);
        uint256 fee = (grant.totalClaimed * totalFee) / grant.amount;
       
        uint256 totalRewards = computeGrantReward(msg.sender);
        uint256 rewards = (grant.totalClaimed * totalRewards) / grant.amount;

        grant.remainingVeLndx -= veLNDXAmount;
        grant.remainingRewards = totalRewards - rewards;
        grant.remainingFee = totalFee - fee;
        rewardsPerGrant[msg.sender]  = grant.remainingVeLndx * rewardSharesPerToken / 1e6;
        feePerGrant[msg.sender]  = grant.remainingVeLndx * feeSharesPerToken / 1e6;
        IERC20(usdc).transfer(msg.sender, fee);
        _transfer(address(this), grant.recipient,  amountVested + rewards);
        emit GrantTokensClaimed(grant.recipient, amountVested);
    }

    function computeGrantReward(address recipient)
        public
        view
        returns (uint256)
    {
        Grant storage grant = grants[recipient];
        return
            (grant.remainingVeLndx * rewardSharesPerToken) /
            1e6 -
            rewardsPerGrant[recipient] + grant.remainingRewards;
    }

    function computeGrantFee(address recipient) public view returns (uint256) {
        Grant storage grant = grants[recipient];
        return
            (grant.remainingVeLndx  * feeSharesPerToken) /
            1e6 -
            feePerGrant[recipient] +  grant.remainingFee;
    }

    function _rewardsToDistribute() internal {
      if (rewardVested.amountVested >= MAX_REWARD_AMOUNT) {
            return;
        }

        if (rewardVested.vestingStartedAt == 0) {
            rewardVested.vestingStartedAt = block.timestamp;
        }

         if (rewardVested.lastVestedAt == 0) {
            rewardVested.lastVestedAt = block.timestamp;
        }

        uint256 elapsedDays = (block.timestamp - rewardVested.lastVestedAt) / 1 days;

        uint256 amountVested = 0;

        if (elapsedDays > 0) {
            uint256 amountVestedPerDay = MAX_REWARD_AMOUNT / uint256(rewardVestingDuration);
            amountVested = amountVestedPerDay * elapsedDays;

            if ((amountVested + rewardVested.amountVested) > MAX_REWARD_AMOUNT) {
                amountVested = MAX_REWARD_AMOUNT - rewardVested.amountVested;
                elapsedDays = rewardVestingDuration - rewardVested.daysClaimed;
            }
                
                rewardVested.daysClaimed += elapsedDays;
                rewardVested.amountVested += amountVested;
                rewardVested.lastVestedAt = block.timestamp;

                 _mint(address(this), amountVested);

                 uint256 tokensCount = IERC20(veLNDX).totalSupply();
                if (tokensCount == 0) {
                    rewardNotDistributed += amountVested;
                    return;
                }
                rewardSharesPerToken +=
                    (1e6 * (amountVested + rewardNotDistributed)) /
                    tokensCount;
                rewardNotDistributed = 0;
        }
    }

    function calculateGrantClaim(address _recipient) public view returns (uint256, uint256)  {
        Grant storage grant = grants[_recipient];
        require(grant.totalClaimed < grant.amount, "grant fully claimed");
        // For grants created with a future start date, that hasn't been reached, return 0, 0
        if (block.timestamp < grant.startTime) {
            return (0, 0);
        }

        // Check cliff was reached
        uint256 elapsedDays = (block.timestamp - grant.startTime) / 1 days;

        // If over vesting duration, all tokens vested
        if (elapsedDays >= grant.vestingDuration) {
            uint256 remainingGrant = grant.amount - grant.totalClaimed;
            return (grant.vestingDuration - grant.daysClaimed, remainingGrant);
        } else {
            uint256 daysVested = elapsedDays - grant.daysClaimed;
            uint256 amountVestedPerDay = grant.amount / grant.vestingDuration;
            uint256 amountVested = daysVested * amountVestedPerDay;
            return (daysVested, amountVested);
        }
    }

    /**
    Staking logic
    */
     function feeToDistribute(uint256 amount)
        external
        onlyRole(FEE_DISTRIBUTOR)
    {
        uint256 tokensCount = IERC20(veLNDX).totalSupply();
        if (tokensCount == 0) {
            feeNotDistributed += amount;
            return;
        }
        feeSharesPerToken += (1e6 * (amount + feeNotDistributed)) / tokensCount;
        feeNotDistributed = 0;
    }

    function stakeLNDX(uint256 amount, StakePeriods period) external {
        require(coefficients[period] != 0, "wrong period");
        _transfer(msg.sender, address(this), amount);
        uint256 mintAmount = (amount * coefficients[period]) / 100; //veLNDX amount to mint
        IveLNDX(veLNDX).mint(msg.sender, mintAmount);
        _rewardsToDistribute();
        Stake memory stake = Stake({
            staker: msg.sender,
            amount: amount,
            startTime: block.timestamp,
            endTime: _calculateEndDate(period),
            unstaked: false,
            veLndxClaimed: mintAmount
        });
        stakesCount++;
        stakes[stakesCount] = stake;

        totalStaked += amount;
        staked[msg.sender] += amount;

        feePerStake[stakesCount] += (feeSharesPerToken * mintAmount) / 1e6;
        rewardsPerStake[stakesCount] +=
            (rewardSharesPerToken * mintAmount) /
            1e6;

        emit Staked(msg.sender, amount, stakesCount, stake.endTime);
    }

    function unstake(uint256 stakeID) external {
        require(stakes[stakeID].staker == msg.sender, "not staker");
        require(stakes[stakeID].unstaked == false, "already unstaked");
        require(stakes[stakeID].endTime <= block.timestamp, "too early");

        Stake storage s = stakes[stakeID];
        totalStaked -= s.amount;
        staked[msg.sender] -= s.amount;

        _rewardsToDistribute();

        uint256 rewards = computeStakeReward(stakeID);
        uint256 fee = computeStakeFee(stakeID);

        stakerClaimed[s.staker][0] += fee;
        stakerClaimed[s.staker][1] += rewards;

        s.unstaked = true;

        rewardsPerStake[stakeID] = 0;
        feePerStake[stakeID] = 0;

        _transfer(address(this), msg.sender, s.amount + rewards);
        IveLNDX(veLNDX).burn(msg.sender, s.veLndxClaimed);
        IERC20(usdc).transfer(msg.sender, fee);
        emit Unstaked(msg.sender, s.amount, stakeID);
    }

    function _rewardsToDistributePreview() internal  view returns (uint256){
      if (rewardVested.amountVested >= MAX_REWARD_AMOUNT) {
            return 0;
        }

        uint256 vestingStartedAt = rewardVested.vestingStartedAt;
        uint256 lastVestedAt = rewardVested.lastVestedAt;

        if (vestingStartedAt == 0) {
              vestingStartedAt = block.timestamp;
        }

         if (lastVestedAt == 0) {
            lastVestedAt = block.timestamp;
        }

        uint256 elapsedDays = (block.timestamp - lastVestedAt) / 1 days;

        uint256 amountVested = 0;

        if (elapsedDays > 0) {
            uint256 amountVestedPerDay = MAX_REWARD_AMOUNT / uint256(rewardVestingDuration);
            amountVested = amountVestedPerDay * elapsedDays;

            if ((amountVested + rewardVested.amountVested) > MAX_REWARD_AMOUNT) {
                amountVested = MAX_REWARD_AMOUNT - rewardVested.amountVested;
                elapsedDays = rewardVestingDuration - rewardVested.daysClaimed;
            }

                 uint256 tokensCount = IERC20(veLNDX).totalSupply();
                 uint256  _rewardNotDistributed = rewardNotDistributed;
                if (tokensCount == 0) {
                    _rewardNotDistributed += amountVested;
                    return 0;
                }
                return (rewardSharesPerToken +
                    (1e6 * (amountVested + _rewardNotDistributed)) /
                    tokensCount);
        }
        return rewardSharesPerToken;
    }

    function unstakePreview(uint256 stakeID)
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        require(stakes[stakeID].unstaked == false, "already unstaked");

        Stake storage s = stakes[stakeID];
        uint256 _rewardSharesPerToken = _rewardsToDistributePreview();

        uint256 rewards = (s.veLndxClaimed * _rewardSharesPerToken) / 1e6 - rewardsPerStake[stakeID];
        uint256 fee = computeStakeFee(stakeID);

        return (s.amount, fee, rewards);
    }

    function computeStakeReward(uint256 stakeID) public view returns (uint256) {
        Stake storage stake = stakes[stakeID];
        return
            (stake.veLndxClaimed * rewardSharesPerToken) /
            1e6 -
            rewardsPerStake[stakeID];
    }

    function computeStakeFee(uint256 stakeID) public view returns (uint256) {
        Stake storage stake = stakes[stakeID];
        return
            (stake.veLndxClaimed * feeSharesPerToken) /
            1e6 -
            feePerStake[stakeID];
    }

    function _calculateEndDate(StakePeriods period)
        internal
        view
        returns (uint256)
    {
        if (period == StakePeriods.MONTHS_3) {
            return (block.timestamp + 90 days);
        }
        if (period == StakePeriods.MONTHS_12) {
            return (block.timestamp + 365 days);
        }
        if (period == StakePeriods.MONTHS_48) {
            return (block.timestamp + 4 * 365 days);
        }
        return 0;
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function renounceOwnership() public view override onlyOwner {
        revert ("can 't renounceOwnership here");
    }
}
