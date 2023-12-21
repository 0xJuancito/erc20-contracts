// SPDX-License-Identifier: ISC

pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "../interfaces/IFundManager.sol";
import "../interfaces/IRewardManager.sol";
import "./abstract/AbstractYielder.sol";
import "./RewardFeeProvider.sol";

contract RewardManager is AbstractYielder, IRewardManager {
    struct AddressRewardLog {
        uint256 lastClaimTime;
        bool excludedFromFee;
    }

    // The minium balance of Tokens an address must have in order for it to receive a reward
    uint256 public minRewardBalance = 1_000_000 * 10 ** 18;
    IFund public fund;
    IERC20 public token;
    RewardFeeProvider public feeProvider;

    address public feeAddress;
    mapping(address => AddressRewardLog) public rewardLogBook;

    event ActivateRewards(address _address);

    modifier mustHaveFundSet() {
        require(address(fund) != address(0), "No Fund contract was set");
        _;
    }

    modifier notExcluded(address account) {
        if (isExcluded(account)) {
            return;
        }
        _;
    }

    modifier onlyTokenContractOrOwner() {
        require(msg.sender == address(token) || msg.sender == address(owner()), "Only token contract can call this function");
        _;
    }

    constructor(ERC20 _token, address _feeAddress) {
        token = _token;
        feeAddress = _feeAddress;
    }

 
    function notifyBalanceUpdate(address _address, uint256 prevBalance) external override onlyTokenContractOrOwner notExcluded(_address) {
        uint256 balance = token.balanceOf(_address);
        // Calculate balanceDiff
        if (prevBalance > balance) {
            handleBalanceDecrease(_address, balance);
            return;
        }

        if (prevBalance < balance) {
            handleBalanceIncrease(_address, balance);

            // User entered the reward pool, set last claim time to now
            if (prevBalance < minRewardBalance && balance >= minRewardBalance) {
                rewardLogBook[_address].lastClaimTime = block.timestamp; 
            }
            return;
        }
    }
    
    function unclaimedRewardValue(address _address) public view override returns (uint256) {
        return _pendingReward(_address);
    }

    function setFundAddress(address newAddress) public onlyOwner {
        require(address(fund) != newAddress, "New address is the same as old address");
        require(address(0) != newAddress, "Fund address cannot be address(0)");
        fund = IFund(newAddress);
    }

    function setTokenAddress(address newAddress) public onlyOwner {
        require(address(token) != newAddress, "New address is the same as old address"); 
        require(address(0) != newAddress, "Token address cannot be address(0)");
        token = IERC20(newAddress);
    }

    function setFeeAddress(address newAddress) public onlyOwner {
        require(address(feeAddress) != newAddress, "New address is the same as old address"); 
        require(address(0) != newAddress, "Fee address cannot be address(0)"); 
        feeAddress = newAddress;
    }

    function setFeeProvider(address newAddress) public onlyOwner {
        require(address(feeProvider) != newAddress, "New address is the same as old address");
        require(address(0) != newAddress, "Provider address cannot be address(0)");
        feeProvider = RewardFeeProvider(newAddress);
    }

    function updateMinRewardBalance(uint256 _minRewardBalance) external onlyOwner {
        minRewardBalance = _minRewardBalance;
    }

    function banAddress(address _address) external onlyOwner {
        excludeAddress(_address);
        InvestorInfo storage user = investorInfo[_address];
        try fund.claimTo(user.leftToClaim, feeAddress) {} catch {}
        user.leftToClaim = 0;
    }

    function includeAddress(address _address) public virtual override onlyOwner {
        super.includeAddress(_address);
        handleBalanceIncrease(_address, token.balanceOf(_address));
    }

    function rewardEligible(address _address) external view returns (bool) {
        return investorInfo[_address].amount >= minRewardBalance;
    }

    function destroy() external onlyOwner {
        selfdestruct(payable(msg.sender));
    }

    function _totalReward() internal view override returns (uint256) {
        return fund.pendingRewards();
    }

    function _sweepOutstandingReward(uint256 reward) internal override {
          if(reward > 0) {
            fund.claimTo(reward, feeAddress);
        }
    }

    function _claimReward(uint256 reward, address receiver) internal override {
        uint256 feeValue = caculateClaimFee(msg.sender, reward);
        fund.claimTo(reward - feeValue, receiver);
        fund.claimTo(feeValue, feeAddress);

        // In case the reward manager was paused, handle balance decrease to avoid leeches
        uint256 currentDeposited = investorInfo[msg.sender].amount;
        uint256 currentBalance = token.balanceOf(msg.sender);
        rewardLogBook[msg.sender].lastClaimTime = block.timestamp; 

        if (currentBalance < currentDeposited) {
            handleBalanceDecrease(msg.sender, currentBalance);
            return;
        } 

        if (currentBalance < minRewardBalance && currentBalance > 0) {
            withdrawFrom(0, msg.sender);
        }
    }


    function handleBalanceDecrease(address _address, uint256 currentBalance) internal {
        uint256 amount = investorInfo[_address].amount;
        if (currentBalance < minRewardBalance && amount > 0) {
            withdrawFrom(0, _address);
            return;
        }

        if (currentBalance >= minRewardBalance) {
            // Bring balances back in sync in case reward manager does not get notified of transfers
            if (amount > currentBalance) {
                withdrawFrom(amount - currentBalance, _address);
            } 
            
            if(amount < currentBalance) {
                depositTo(currentBalance - amount, _address);
            }
        }
    }

    function handleBalanceIncrease(address _address, uint256 currentBalance) internal {
        if (currentBalance < minRewardBalance) {
            return;
        }

        // Bring balances back in sync in case reward manager does not get notified of transfers
        uint256 amount = investorInfo[_address].amount;
        if(currentBalance > amount) {
            depositTo(currentBalance - amount, _address);
        } 

        if(currentBalance < amount) {
            withdrawFrom(amount - currentBalance, _address);
        }
    }

    // Can be used to manually activate the rewards, in case the threshold changes
    function activateRewards(address _address) external {
        require(!isExcluded(_address), "Address is excluded");
        uint256 balance = token.balanceOf(_address);
        require(balance >= minRewardBalance, "Insufficient balance");
        handleBalanceIncrease(_address, balance);
        emit ActivateRewards(_address);
    }

    function fee(address _address) public view override returns (uint256) {
        AddressRewardLog memory log = rewardLogBook[_address];
        if (log.excludedFromFee || address(feeProvider) == address(0)) {
            return 0;
        }
        return feeProvider.getClaimFee(log.lastClaimTime);
    }

    function caculateClaimFee(address _address, uint256 amount) internal view returns (uint256) {
        AddressRewardLog memory log = rewardLogBook[_address];
        if (log.excludedFromFee || address(feeProvider) == address(0)) {
            return 0;
        }
        return feeProvider.caculateClaimFee(log.lastClaimTime, amount);
    }

    // No need to implement these
    function deposit(uint256 amount) override virtual public onlyOwner {}
    function withdraw(uint256 amount) override virtual public onlyOwner {}
    function _deposit(uint256 amount, address sender) internal override   {}
    function _withdraw(uint256 amount, address receiver) internal override  {}

    receive() external payable {
        revert();
    }

}
