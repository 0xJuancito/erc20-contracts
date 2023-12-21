// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";

import "./owner/Operator.sol";

/*

██████╗  ██╗ ██████╗  ███████╗     ███╗   ███╗  ██████╗  ███╗   ██╗ ███████╗ ██╗   ██╗
██╔══██╗ ██║ ██╔══██╗ ██╔════╝     ████╗ ████║ ██╔═══██╗ ████╗  ██║ ██╔════╝ ╚██╗ ██╔╝
██║  ██║ ██║ ██████╔╝ ███████╗     ██╔████╔██║ ██║   ██║ ██╔██╗ ██║ █████╗    ╚████╔╝ 
██║  ██║ ██║ ██╔══██╗ ╚════██║     ██║╚██╔╝██║ ██║   ██║ ██║╚██╗██║ ██╔══╝     ╚██╔╝  
██████╔╝ ██║ ██████╔╝ ███████║ ██╗ ██║ ╚═╝ ██║ ╚██████╔╝ ██║ ╚████║ ███████╗    ██║   
╚═════╝  ╚═╝ ╚═════╝  ╚══════╝ ╚═╝ ╚═╝     ╚═╝  ╚═════╝  ╚═╝  ╚═══╝ ╚══════╝    ╚═╝   
                                                                             
https://dibs.money

*/
contract DShare is ERC20Burnable, Operator {
    using SafeMath for uint256;

    /*
        TOTAL MAX SUPPLY = 70,000 dSHAREs
        - 36000 dShares allocated to Dibs-BNB
        - 24000 dShares allocated to dShare-BNB
        - Airdop 500 dShares allocated to DAO wallet
        - Allocate 4500 dShares to DAO wallet for linear vesting
        - Airdrop 360 dShares to Dev wallet
        - Allocate 4640 dShares to Dev wallet for linear vesting
    */
    uint256 public constant FARMING_POOL_REWARD_ALLOCATION = 60000 ether;
    uint256 public constant COMMUNITY_FUND_POOL_ALLOCATION = 4500 ether;
    uint256 public constant DEV_FUND_POOL_ALLOCATION = 4640 ether;

    uint256 public constant VESTING_DURATION = 365 days;
    uint256 public startTime;
    uint256 public endTime;

    uint256 public communityFundRewardRate;
    uint256 public devFundRewardRate;

    address public communityFund;
    address public devFund;

    uint256 public communityFundLastClaimed;
    uint256 public devFundLastClaimed;

    bool public rewardPoolDistributed = false;

    constructor(uint256 _startTime, address _daoFund, address _devFund) public ERC20("DSHARE", "DSHARE") {
        _mint(msg.sender, 2 ether);         // mint 2 DIBS Share for initial pools deployment and Piggybank initialization
        _mint(_daoFund, 500 ether);         // Airdop 500 Dshares allocated to DAO wallet
        _mint(_devFund, 358 ether);         // Airdop 358 Dshares allocated to DEV wallet + 2 dShare for initialization

        startTime = _startTime;
        endTime = startTime + VESTING_DURATION;

        communityFundLastClaimed = startTime;
        devFundLastClaimed = startTime;

        communityFundRewardRate = COMMUNITY_FUND_POOL_ALLOCATION.div(VESTING_DURATION);
        devFundRewardRate = DEV_FUND_POOL_ALLOCATION.div(VESTING_DURATION);

        require(_devFund != address(0), "Address cannot be 0");
        devFund = _devFund;

        require(_daoFund != address(0), "Address cannot be 0");
        communityFund = _daoFund;
    }

    function setTreasuryFund(address _daoFund) external {
        require(msg.sender == devFund, "!dev");
        communityFund = _daoFund;
    }

    function setDevFund(address _devFund) external {
        require(msg.sender == devFund, "!dev");
        require(_devFund != address(0), "zero");
        devFund = _devFund;
    }

    function unclaimedTreasuryFund() public view returns (uint256 _pending) {
        uint256 _now = block.timestamp;
        if (_now > endTime) _now = endTime;
        if (communityFundLastClaimed >= _now) return 0;
        _pending = _now.sub(communityFundLastClaimed).mul(communityFundRewardRate);
    }

    function unclaimedDevFund() public view returns (uint256 _pending) {
        uint256 _now = block.timestamp;
        if (_now > endTime) _now = endTime;
        if (devFundLastClaimed >= _now) return 0;
        _pending = _now.sub(devFundLastClaimed).mul(devFundRewardRate);
    }

    /**
     * @dev Claim pending rewards to community and dev fund
     */
    function claimRewards() external {
        uint256 _pending = unclaimedTreasuryFund();
        if (_pending > 0 && communityFund != address(0)) {
            _mint(communityFund, _pending);
            communityFundLastClaimed = block.timestamp;
        }
        _pending = unclaimedDevFund();
        if (_pending > 0 && devFund != address(0)) {
            _mint(devFund, _pending);
            devFundLastClaimed = block.timestamp;
        }
    }

    /**
     * @notice distribute to reward pool (only once)
     */
    function distributeReward(address _farmingIncentiveFund) external onlyOperator {
        require(!rewardPoolDistributed, "only can distribute once");
        require(_farmingIncentiveFund != address(0), "!_farmingIncentiveFund");
        rewardPoolDistributed = true;
        _mint(_farmingIncentiveFund, FARMING_POOL_REWARD_ALLOCATION);
    }

    function burn(uint256 amount) public override {
        super.burn(amount);
    }

    function governanceRecoverUnsupported(
        IERC20 _token,
        uint256 _amount,
        address _to
    ) external onlyOperator {
        _token.transfer(_to, _amount);
    }
}
