pragma solidity ^0.8.9;

import "../interface/IERC20.sol";
import "../libs/DateTime.sol";

//counter address for number of restaking

contract TAF90DaysStaking {

    IERC20 public stakingToken;

    uint256 public apy;
    uint256 public totalSupply;
    uint256 public withdrawFee;
    uint256 public rollOverFee;
    uint256 public unstakePenalty;
    uint256 public maxTotalStakingAmount;
    uint256 public poolExpiry;
    uint256 public maxUserStakingAmount;
    uint256 public minUserStakingAmount;

    address public owner;
    address public charityAddress;

    bool public paused;

    mapping(address => uint256) public balances;
    mapping(address => uint256) public rewardsOut;
    mapping(address => uint256) public timestamp;

    modifier onlyOwner {
      require(msg.sender == owner);
      _;
   }


    constructor(uint256 _apy, address _stakingToken, uint256 _maxTotalStakingAmount, uint256 maxUS, uint256 minUS){
        apy = _apy;
        stakingToken = IERC20(_stakingToken);
        maxTotalStakingAmount = _maxTotalStakingAmount;

        minUserStakingAmount = minUS;
        maxUserStakingAmount = maxUS;

        withdrawFee = 200;
        rollOverFee = 100;

        owner = msg.sender;
        charityAddress = msg.sender;

        paused = true;
    }

    function startStaking(uint256 _unstakeMaxFee) onlyOwner public{
        poolExpiry = block.timestamp + 21 days;
        paused = false;

        unstakePenalty = _unstakeMaxFee;
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

    function updateWithdrawFee(uint256 amount) onlyOwner public{
        withdrawFee = amount;
    }

    function updateRollOverFee(uint256 amount) onlyOwner public{
        rollOverFee = amount;
    }

    function updateOwner(address user) onlyOwner public{
        owner = user;
    }

    function updateAPY(uint256 _apy) onlyOwner public{
        apy = _apy;
    }

    function togglePause() onlyOwner public{
        paused = !paused;
    }

    function stake(uint _amount) public{
        require(!paused, "Staking contract is paused!");
        require(block.timestamp < poolExpiry, "Staking contract is over!");

        if(minUserStakingAmount > 0)
            require(_amount >= minUserStakingAmount, "Must be above min user staking amount");

        if(maxUserStakingAmount > 0)
            require(balances[msg.sender] + _amount <= maxUserStakingAmount, "Must be less then max user staking amount");

        if(maxTotalStakingAmount > 0)
            require(totalSupply + _amount <= maxTotalStakingAmount, "Max Staking amount reached");

        if(balances[msg.sender] > 0)
            withdrawReward();
        
        totalSupply += _amount;
        balances[msg.sender] += _amount;

        stakingToken.transferFrom(msg.sender, address(this), _amount);
        timestamp[msg.sender] = block.timestamp;
        rewardsOut[msg.sender] = 0;
    }

    function unstake(uint256 _amount) public{
        require(block.timestamp > poolExpiry + 7 days, "Can only withdraw once the time is right");
        require(balances[msg.sender] >= _amount, "Not have enough balance");
        
        uint256 fee = (_amount * withdrawFee)/10000;

        if(_amount > 0)
            stakingToken.transfer(msg.sender, _amount - fee);


        if(fee > 0)
            stakingToken.transfer(owner, fee);


        if(earned() > 0)
            stakingToken.transfer(msg.sender, earned());


        totalSupply -= _amount;
        balances[msg.sender] -= _amount;
        timestamp[msg.sender] = block.timestamp;
        rewardsOut[msg.sender] = 0;
    }

    function forceUnstake(uint256 _amount) public{
        require(block.timestamp < poolExpiry + 7 days, "Please use unstake function instead.");
        require(balances[msg.sender] >= _amount, "Not have enough balance");

        uint256 minDiff = BokkyPooBahsDateTimeLibrary.diffMinutes(block.timestamp, poolExpiry + 7 days);

        uint256 fee = 0;

        if(unstakePenalty > 0)
            fee = (minDiff * unstakePenalty * _amount) / (2800 * 24 * 60);

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
    }


    function earned() public view returns(uint256){

        uint256 dayDiff = BokkyPooBahsDateTimeLibrary.diffMinutes(timestamp[msg.sender], block.timestamp > poolExpiry ? poolExpiry : block.timestamp);

        uint256 reward = (apy * balances[msg.sender] * dayDiff ) / (365 * 24 * 60 * 10000);

        return reward - rewardsOut[msg.sender];
    }

    function withdrawReward() public{

        uint256 amount = earned();

        uint256 fee = (withdrawFee * amount) / 10000;

        stakingToken.transfer(msg.sender, amount - fee);

        if(fee > 0)
            stakingToken.transfer(owner, fee);

        rewardsOut[msg.sender] += amount;
    }

    function depositRewardToken(uint256 _amount) public{
        stakingToken.transferFrom(msg.sender, address(this), _amount);

    }

    function withdrawRewardToken(uint256 _amount) onlyOwner public{
        stakingToken.transfer(msg.sender, _amount);

    }

    function timings() public view returns (uint256, uint256){
        return (timestamp[msg.sender], poolExpiry + 7 days);
    }

    function userInfo() public view returns (uint256, uint256, uint256, uint256){
        (uint256 start, uint256 end) = timings();
        return (balances[msg.sender], earned(), start, end);
    }

    function isForceUnstakeNeeded() public view returns(bool){
        return block.timestamp < poolExpiry + 7 days;
    }
}