pragma solidity ^0.8.9;

import "../interface/IERC20.sol";
import "../libs/DateTime.sol";

contract TAFYearlyStaking{

    IERC20 public immutable stakingToken;

    uint256 public immutable lockingPeriodInYears;
    uint256 public totalSupply;
    uint256 public stakingFee;
    uint256 public rewardFee;
    uint256 public unstakePenalty;
    uint256 public maxTotalStakingAmount;
    uint256 public maxUserStakingAmount;
    uint256 public minUserStakingAmount;
    uint256 public totalActiveUsers;
    uint256 public apy;

    address public owner;

    bool public paused;

    mapping(address => uint256) public balances;
    mapping(address => uint256) public rewardsOut;
    mapping(address => uint256) public timestamp;
    mapping(uint256 => uint256) public apyOnYear;
    mapping(address => bool) public isUserActive;

    modifier onlyOwner {
      require(msg.sender == owner);
      _;
   }

    constructor(address _stakingToken, uint256 _lockingPeriodInYears, uint256 _apy){
        stakingToken = IERC20(_stakingToken);
        lockingPeriodInYears = _lockingPeriodInYears;

        stakingFee = 200;
        unstakePenalty = 80;

        apy = _apy;
        owner = msg.sender;
    }

    function setYearApy(uint256 year, uint256 _apy) onlyOwner public{
        apyOnYear[year] = _apy;
    }

    function updateUnstakePenalty(uint256 amount) onlyOwner public {
        unstakePenalty = amount;
    }

    function updateMaxStakingAmount(uint256 amount) onlyOwner public{
        maxTotalStakingAmount = amount;
    }

    function updateMinUserStakingAmount(uint256 amount) onlyOwner public{
        minUserStakingAmount = amount;
    }

    function updateMaxUserStakingAmount(uint256 amount) onlyOwner public{
        maxUserStakingAmount = amount;
    }

    function updateStakingFee(uint256 amount) onlyOwner public{
        stakingFee = amount;
    }

    function updateRewardFee(uint256 amount) onlyOwner public{
        rewardFee = amount;
    }

    function updateOwner(address user) onlyOwner public{
        require(user != address(0), "Owner Address can not be null");
        owner = user;
    }

    function togglePause() onlyOwner public{
        paused = !paused;
    }

    function depositRewardToken(uint256 _amount) public{
        stakingToken.transferFrom(msg.sender, address(this), _amount);
    }

    function withdrawRewardToken(uint256 _amount) onlyOwner public{
        stakingToken.transfer(msg.sender, _amount);
    }

    function timings() public view returns (uint256, uint256){
        return (timestamp[msg.sender], BokkyPooBahsDateTimeLibrary.addYears(timestamp[msg.sender], lockingPeriodInYears));
    }

    function userInfo() public view returns (uint256, uint256, uint256, uint256){
        (uint256 start, uint256 end) = timings();
        return (balances[msg.sender], earned(), start, end);
    }

    function updateAPY(uint256 _apy) public{
        apy = _apy;
    }

    function isForceUnstakeNeeded() public view returns(bool){
        return block.timestamp < BokkyPooBahsDateTimeLibrary.addYears(timestamp[msg.sender], lockingPeriodInYears);
    }

    function stake(uint _amount) public{
        require(!paused, "Staking contract is paused!");

        if(minUserStakingAmount > 0)
            require(_amount >= minUserStakingAmount, "Must be above min user staking amount");

        if(maxUserStakingAmount > 0)
            require(balances[msg.sender] + _amount <= maxUserStakingAmount, "Must be less then max user staking amount");

        if(maxTotalStakingAmount > 0)
            require(totalSupply + _amount <= maxTotalStakingAmount, "Max Staking amount reached");


        require(balances[msg.sender] == 0, "Can not restake");


        uint256 fee = (_amount * stakingFee) / 10000;
        
        totalSupply += _amount - fee;
        balances[msg.sender] += _amount - fee;

        stakingToken.transferFrom(msg.sender, address(this), _amount);

        if(fee > 0)
            stakingToken.transfer(owner, fee);

        timestamp[msg.sender] = block.timestamp;
        rewardsOut[msg.sender] = 0;

        if(!isUserActive[msg.sender]){
            totalActiveUsers++;
            isUserActive[msg.sender] = true;
        }
    }

    function unstake(uint256 _amount) public{
        require(block.timestamp > BokkyPooBahsDateTimeLibrary.addYears(timestamp[msg.sender], lockingPeriodInYears), "Can only withdraw once the time is right");
        require(balances[msg.sender] >= _amount, "Not have enough balance");

        if(_amount > 0)
            stakingToken.transfer(msg.sender, _amount);

        if(earned() > 0)
            stakingToken.transfer(msg.sender, earned());

        totalSupply -= _amount;
        balances[msg.sender] -= _amount;
        timestamp[msg.sender] = block.timestamp;
        rewardsOut[msg.sender] = 0;

        if(balances[msg.sender] == 0){
            totalActiveUsers--;
            isUserActive[msg.sender] = false;
        }
    }

    function forceUnstake(uint256 _amount) public{
        require(block.timestamp < BokkyPooBahsDateTimeLibrary.addYears(timestamp[msg.sender], lockingPeriodInYears), "Can only withdraw once the time is right");
        require(balances[msg.sender] >= _amount, "Not have enough balance");

        uint256 expiryDay = BokkyPooBahsDateTimeLibrary.addYears(timestamp[msg.sender], lockingPeriodInYears);
        uint256 minDiff =  BokkyPooBahsDateTimeLibrary.diffMinutes(block.timestamp, expiryDay);

        uint256 fee = 0;

        if(unstakePenalty > 0)
            fee = (minDiff * unstakePenalty * _amount) / (lockingPeriodInYears * 52560000);

        if(earned() > 0)
            stakingToken.transfer(msg.sender, earned());

        if(_amount - fee > 0)
            stakingToken.transfer(msg.sender, _amount - fee);

        if(fee > 0)
            stakingToken.transfer(owner, fee);


        totalSupply -= _amount;
        balances[msg.sender] -= _amount;
        timestamp[msg.sender] = block.timestamp;
        rewardsOut[msg.sender] = 0;

        if(balances[msg.sender] == 0){
            totalActiveUsers--;
            isUserActive[msg.sender] = false;
        }
    }

    function earned() public view returns(uint256){

        uint256 reward = 0;

        uint256 yearDiff = BokkyPooBahsDateTimeLibrary.diffYears(timestamp[msg.sender], block.timestamp);

        uint256 thisYearMinDiff = BokkyPooBahsDateTimeLibrary.diffMinutes(timestamp[msg.sender], block.timestamp) - (yearDiff * 525600);

        for(uint i = 1; i<= yearDiff; i++){
            reward += (apyOnYear[i] * balances[msg.sender]) / 10000;
        }

        if(thisYearMinDiff > 0)
            reward += (apyOnYear[yearDiff + 1] * balances[msg.sender] * thisYearMinDiff ) / (365 * 24 * 60 * 10000);

        return reward - rewardsOut[msg.sender];
    }


    function withdrawReward() public{

        uint256 amount = earned();

        uint256 fee = (rewardFee * amount) / 10000;

        stakingToken.transfer(msg.sender, amount - fee);

        if(fee > 0)
            stakingToken.transfer(owner, fee);

        rewardsOut[msg.sender] += amount;
    }
}