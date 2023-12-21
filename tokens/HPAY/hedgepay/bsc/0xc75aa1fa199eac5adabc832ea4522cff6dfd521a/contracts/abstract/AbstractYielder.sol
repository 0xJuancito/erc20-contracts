// SPDX-License-Identifier: ISC

pragma solidity 0.8.9;

import "../../interfaces/IYielder.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract AbstractYielder is IYielder, Pausable, Ownable {

    struct InvestorInfo {
        uint256 amount;
        uint256 joinRound;
        uint256 claimed;
        uint256 leftToClaim;
        bool inBlackList;
    }

    struct RoundInfo {
        uint256 points;
        uint256 multiplier;
        uint256 depositSnapshot;
        uint256 globalMultiplierSnapshot;
    }

    uint256 public totalDeposited;
    
    uint256 public totalClaimed;
    uint256 public totalLeftToClaim;
    uint256 public currentRound = 1;
    uint256 public globalRewardMultiplier = 1000;
    uint256 public currentReward;
    uint256 public rewardPoints;

    mapping(uint256 => RoundInfo) public roundInfo;
    mapping(address => InvestorInfo) public investorInfo;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Claim(address indexed user, address receiver, uint256 amount);
    event SweepOutstanding(uint256 amount);
    // Calculates the total rewards
    function _totalReward() internal virtual view returns (uint256);
    
    // Called whenever a rewards reqests a claim
    function _claimReward(uint256 reward, address receiver) virtual internal;

    // Called when shareholder number increases from 0 to 1, it should remove all the rewards generated while there were
    // no shareholder active
    function _sweepOutstandingReward(uint256 reward) virtual internal;

    // Handles fund transfers on deposit
    function _deposit(uint256 amount, address _sender) virtual internal;
    
    // Handles fund transfer on witdraw
    function _withdraw(uint256 amount, address _receiver) virtual internal;

    // Returns the pending reward for a given investor
    function pendingReward(address _investor) override virtual public view returns (uint256) {
        return _pendingReward(_investor);
    }  

    function sweepOutstandingReward() public {
        if(totalDeposited == 0) {
            uint256 reward = _totalReward();

            if(reward > totalLeftToClaim){
                _sweepOutstandingReward(reward - totalLeftToClaim);
                emit SweepOutstanding(reward - totalLeftToClaim);
            }
       }
    }

    function excludeAddress(address _blacklistAddress) public virtual onlyOwner {
        InvestorInfo storage investor =  investorInfo[_blacklistAddress];
        require(!investor.inBlackList, "Investor already in blacklist");
       
        updateRoundInfo();
        
        uint256 rewardShare = calculateRewardShare(investor, rewardPoints);
        investor.leftToClaim += rewardShare;
        totalLeftToClaim += rewardShare;
        investor.inBlackList = true;
        investor.joinRound = currentRound;
        totalDeposited -= investor.amount; 
        investor.amount = 0;
        updateMultiplierAndPoints();
    }

    function includeAddress(address _blacklistAddress) public virtual onlyOwner {
        InvestorInfo storage investor =  investorInfo[_blacklistAddress];
        require(investor.inBlackList, "Investor not in blacklist");
        updateRoundInfo();
       
        investor.inBlackList = false;
        investor.joinRound = currentRound;
        totalDeposited += investor.amount;

        updateMultiplierAndPoints();
    }

    function isExcluded(address _address) public view returns(bool) {
       return investorInfo[_address].inBlackList;
    }

    function calculateRewardShare(InvestorInfo memory _userInfo, uint256 _rewardPoints) internal view returns (uint256) {
        if(_userInfo.inBlackList || totalDeposited == 0) {
            return 0;
        }
    
        uint256 rewardPointShare = calculateRewardPointShare(_userInfo, _rewardPoints);

        uint256 poolShare = (_userInfo.amount * 100000) / totalDeposited;
        uint256 rewardValue = (rewardPointShare * poolShare) / 100000;
        return rewardValue;
    }

    function calculateRewardPointShare(InvestorInfo memory _userInfo, uint256 _rewardPoints) internal view returns (uint256) {
        uint256 globalMultiplerOnJoin = getGlobalMultiplierSnapshot(_userInfo.joinRound);
        uint256 joinRoundMultiplier = getRoundMultiplier(_userInfo.joinRound);
     
        uint256 rewardDebt = getRewardDebt(_userInfo.joinRound);
        uint256 roundMultiplier = getRoundMultiplier(currentRound);

        if(currentRound > _userInfo.joinRound) {
            rewardDebt = (rewardDebt  * globalRewardMultiplier * roundMultiplier ) / (globalMultiplerOnJoin * joinRoundMultiplier);
        }

        return _rewardPoints - rewardDebt;
    }

    function getGlobalMultiplierSnapshot(uint256 round) internal view returns (uint256) {
        uint256 result = roundInfo[round].globalMultiplierSnapshot;
        if (result == 0) {
            return 1000;
        }
        return result;
    }

    function getRoundMultiplier(uint256 round) internal view returns (uint256) {
        uint256 result = roundInfo[round].multiplier;
        if (result == 0) {
            return 1000;
        }
        return result;
    }

    function setRoundMultiplier(uint256 round, uint256 value) internal {
        roundInfo[round].multiplier = value;
    }

    function getRoundPoints(uint256 round) internal view returns (uint256) {
        return roundInfo[round].points;
    }

    function getRewardDebt(uint256 round) internal view returns (uint256) {
        return (getRoundPoints(round) * getRoundMultiplier(round)) / 1000;
    }

    function getDepositAmountSnapshot(uint256 round) internal view returns (uint256) {
       return roundInfo[round].depositSnapshot;
    }

    function updateRoundInfo() internal {
        uint256 totalRewards = totalReward();
        if (currentReward < totalRewards) {
            uint256 roundMultipiler = getRoundMultiplier(currentRound);
            globalRewardMultiplier =  (globalRewardMultiplier * roundMultipiler) / 1000;
            
            currentRound++;
            roundInfo[currentRound].globalMultiplierSnapshot = globalRewardMultiplier;
            
            rewardPoints += totalRewards - currentReward;
            roundInfo[currentRound].points = rewardPoints;
            currentReward = totalRewards;
            roundInfo[currentRound].depositSnapshot = totalDeposited;
        }
    }

    function _pendingReward(address _investor) internal view returns (uint256) {
        InvestorInfo memory user = investorInfo[_investor];

        uint256 _rewardPoints = rewardPoints;
        uint256 totalRewards = totalReward();

        if (currentReward < totalRewards) {
            _rewardPoints += totalRewards - currentReward;
        }

        uint256 reward = calculateRewardShare(user, _rewardPoints);

        return reward + user.leftToClaim;
    }

    function claimRewardTo(uint256 amount, address receiver) override virtual public whenNotPaused {
        updateRoundInfo();
   
        uint256 reward = pendingReward(msg.sender);

        if(amount == 0) {
            amount = reward;
        }
        
        require(reward > 0, "Reward is 0");
        require(reward >= amount, "Inssuficient reward");

        _claimReward(reward, receiver);
        
        InvestorInfo storage user = investorInfo[msg.sender];
        totalLeftToClaim -= user.leftToClaim;
        user.leftToClaim = reward - amount;
        totalLeftToClaim += user.leftToClaim;

        user.joinRound = currentRound;
        
        user.claimed += amount;
        totalClaimed += amount;

        emit Claim(msg.sender, receiver, reward);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    // Claims rewards for the calling investor
    function claimReward(uint256 amount) override virtual external whenNotPaused {
        claimRewardTo(amount, msg.sender);
    }

    function updateMultiplierAndPoints() private  {
        uint256 roundMultipiler = getRoundMultiplier(currentRound);
        uint256 depositSnap = getDepositAmountSnapshot(currentRound);
        if (depositSnap > 0) {
            setRoundMultiplier(currentRound, (totalDeposited * 1000) / depositSnap);
        } 

        roundMultipiler = getRoundMultiplier(currentRound);
        rewardPoints = (roundInfo[currentRound].points * roundMultipiler) / 1000;
    }

    // Yielder may accept funds from investors;
    function deposit(uint256 amount) override virtual external {
       require(depositTo(amount, msg.sender), "Deposit failed");
    }

    function withdraw(uint256 amount) override virtual public {
        require(withdrawFrom(amount, msg.sender), "Withdraw failed");
    }

    function depositTo(uint256 amount, address _address) internal returns(bool) { 
        if(isExcluded(_address)) {
            return false;
        }

        sweepOutstandingReward();
        _depositTo(amount, _address);
        return true;
    }

    function _depositTo(uint256 amount, address _address) internal {
        updateRoundInfo(); 
        
        InvestorInfo storage user = investorInfo[_address];
        uint256 rewardShare = calculateRewardShare(user, rewardPoints);
        user.leftToClaim += rewardShare;
        totalLeftToClaim += rewardShare;

        user.joinRound = currentRound;
        user.amount += amount;
        totalDeposited += amount;

        updateMultiplierAndPoints();
        _deposit(amount, _address);
        emit Deposit(_address, amount);
    }

    function withdrawFrom(uint256 amount, address _address) internal returns(bool) { 
        updateRoundInfo();

        InvestorInfo storage user = investorInfo[_address];
        if(amount == 0) {
            amount = user.amount; 
        }

        if(amount == 0 || amount > user.amount) {
            return false;
        }

        uint256 rewardShare = calculateRewardShare(user, rewardPoints);
        user.leftToClaim += rewardShare;
        totalLeftToClaim += rewardShare;
        
        user.joinRound = currentRound;
        user.amount -= amount;

        totalDeposited -= amount;
        updateMultiplierAndPoints();

        _withdraw(amount, _address); 
        emit Withdraw(_address, amount);
        return true;
    }

    function totalReward() public view returns (uint256) {
        uint256 currentTotalRewards = _totalReward();
        return currentTotalRewards + totalClaimed;
    }
}
