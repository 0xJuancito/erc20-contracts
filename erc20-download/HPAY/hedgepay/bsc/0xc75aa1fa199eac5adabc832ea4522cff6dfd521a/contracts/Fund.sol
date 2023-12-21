// SPDX-License-Identifier: ISC

pragma solidity 0.8.9;


import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import "../interfaces/IFundManager.sol";
import "../interfaces/IInvestmentStrategy.sol";
import "../interfaces/IStash.sol";
import "./abstract/AbstractFund.sol";

contract Fund is AbstractFund {
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    bool claimEnabled = true;
    uint16 public performanceFee = 2;
    uint256 public collectedPerformanceFee ;

    address private vault;
    IRewardStash public rewardStash;

    EnumerableMap.UintToAddressMap private clientIndex;
    mapping(address => FundUtils.FundClient) clients;

    modifier canClaim(uint256 amount) {
        require(claimEnabled, "Fund: Not allowed to claim");
        require(amount > 0 && amount <= _pendingRewards(), "Fund: Not enough funds to claim");
        _;
    }

    constructor(address _stashAddress, address _vault)
        AbstractFund(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56, 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56) {
        rewardStash = IRewardStash(_stashAddress);
        vault = _vault;
    }

    // Add a new strategy
    function addClient(address _clientAddress) external override onlyRole(MANAGER_ROLE) {
        if (clients[_clientAddress].exists) {
            return;
        }
        
        clients[_clientAddress] = FundUtils.FundClient({
            profitAllocation: 0,
            pendingProfit: 0,
            exists: true,
            key: getNewKey()
        });

        clientIndex.set(clients[_clientAddress].key, _clientAddress);
    }

    // Remove a strategy 
    function removeClient(address _clientId, address _fundDestonation) external override onlyRole(MANAGER_ROLE)  {
        if (!clients[_clientId].exists) {
            return;
        }
        uint256 key = clients[_clientId].key;
        uint256 pendingProfit = clients[_clientId].pendingProfit;
        clientIndex.remove(key);
        unallocatedProfit += clients[_clientId].profitAllocation;
        delete clients[_clientId]; 
        _claim(pendingProfit, _fundDestonation);
    }

    function updateProfitAllocation(address _strategyId, uint8 allocation) external override onlyRole(MANAGER_ROLE) {
        require(allocation <= 100, "Allocation overflow");
        FundUtils.FundClient storage fundClient = clients[_strategyId];

        if (fundClient.profitAllocation >= allocation) {
            unallocatedProfit += fundClient.profitAllocation - allocation;
        } else {
            require(fundClient.profitAllocation + unallocatedProfit >= allocation, "Insuficient reserve");
            unallocatedProfit -= allocation - fundClient.profitAllocation;
        }
        fundClient.profitAllocation = allocation;
    }
  
    // Claim BUSD rewards into other address
    function _claim(uint256 amount, address _destination) internal override canClaim(amount) { 
        clients[msg.sender].pendingProfit -= amount;
        rewardStash.unstash(amount);
        rewardAsset.transfer(_destination, amount);
        _updateRewardSnap();
    }

    function _stashProfit(uint256 availableProfit) internal override {
        uint256 fee = (availableProfit * performanceFee) / 100 ;
        rewardAsset.increaseAllowance(address(rewardStash), availableProfit - fee); 
        rewardStash.stash(availableProfit - fee);
        rewardAsset.transfer(_vaultAddress(), fee); 
        collectedPerformanceFee += fee;

        for (uint256 index = 0; index < clientIndex.length(); index++) {
            (, address clientAddress) = clientIndex.at(index);
            FundUtils.FundClient storage client = clients[clientAddress];
            uint256 profitShare = ((availableProfit - fee) * client.profitAllocation) / 100;
            client.pendingProfit += profitShare;
        }
    }

    function _stashCapitalPool(uint256 availableCapital) internal override {
       usd.transfer(_vaultAddress(), availableCapital);
    }

    function _stashETHCapitalPool(uint256 availableCapital) internal override {
        payable(_vaultAddress()).transfer(availableCapital);
    }

    function _vaultAddress() internal view override returns (address) {
        return address(vault);
    }

    function totalGenerateRewards() public override view returns(uint256) {
        uint256 brutReward = rewardStash.stashValue();
        return totalRewardsClaimed + brutReward;
    }

    // Get total pending rewards value of an address in BUSD
    function _pendingRewards() internal view override returns (uint256) {
        return clients[msg.sender].pendingProfit;
    }

     // Get total pending rewards value of an address in BUSD
    function currentStashValue() external view returns (uint256) {
        return rewardStash.stashValue(); 
    }

    function setClaimStatus(bool status) external {
        require(claimEnabled != status, "Status allready set");
        claimEnabled = status;
    }

    function updateVault(address newAddress) external onlyRole(DEFAULT_ADMIN_ROLE) { 
        require(newAddress != address(vault), "Vault Address Unchanged");
        require(newAddress != address(0), "Vault cannot be null");

        vault = newAddress;
    }

    function updateStash(address newAddress) external onlyRole(DEFAULT_ADMIN_ROLE) { 
        require(newAddress != address(rewardStash),"Stash Address Unchanged");
        require(newAddress != address(0), "Stash cannot be null");

        rewardStash = IRewardStash(newAddress);
    }
}
