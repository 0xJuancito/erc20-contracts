// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;

import '../../base/PlainElasticToken.sol';
import "../../../../3rdParty/@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

interface PlainIRewardVault{
    function noticeUnderWaterSell(uint256 inputReward,uint256 sellAmount,uint256 logIndex) external;
    function noticeUnderWaterBuy(uint256 index,address buyer,uint256 amount)external;
}

abstract contract PlainElasticTokenWBase is PlainElasticToken{
    using SafeMathInt for int256;
    using SafeMathUpgradeable for uint256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    bool public usingStrategy;
    EnumerableSetUpgradeable.AddressSet private fromWhitelist;
    EnumerableSetUpgradeable.AddressSet private toWhitelist;
    EnumerableSetUpgradeable.AddressSet private testList;
    EnumerableSetUpgradeable.AddressSet private swapPairs;
    uint256 public totalBurned;

    struct RebaseLog{
        uint256 epoch;
        uint256 time;
        uint256 initTotal;
        int256  supplyDelta;
        uint256 absDelta;
        uint256 burned;
        uint256 rewards;   
    }

    RebaseLog[] public logs;
    uint256 public factor;
    uint256 public burnSplit;
    address public rewardVault;
    uint256 public constant FACTOR_BASE = 1e18;
    uint256[50] private __gap;
    
    function viewFromWhiteList()public view returns(address[] memory,address[] memory){
        uint256 len = fromWhitelist.length();
        address[] memory list = new address[](len);
        for (uint256 x=0;x<len;x++){
            list[x] = fromWhitelist.at(x);
        }
        len = swapPairs.length();
        address[] memory list1 = new address[](len);
        for (uint256 x=0;x<len;x++){
            list1[x] = swapPairs.at(x);
        }
        return (list,list1);
    }
    function viewToWhiteList()public view returns(address[] memory,address[] memory){
        uint256 len = toWhitelist.length();
        address[] memory list = new address[](len);
        for (uint256 x=0;x<len;x++){
            list[x] = toWhitelist.at(x);
        }
        len = swapPairs.length();
        address[] memory list1 = new address[](len);
        for (uint256 x=0;x<len;x++){
            list1[x] = swapPairs.at(x);
        }
        return (list,list1);
    }
    function viewLogsLen()public view returns(uint256){
        return logs.length;
    }

    function isAboveWater() public view returns(bool){
        if (logs.length>0){
            uint256 index = logs.length-1;
            RebaseLog memory lastLog = logs[index];
            if (lastLog.supplyDelta<0){
                return false;
            }
        }
        return true;
    }
    function isUnderWater() public view returns(bool){
        if (logs.length>0){
            uint256 index = logs.length-1;
            RebaseLog memory lastLog = logs[index];
            if (lastLog.supplyDelta<0){
                return true;
            }
        }
        return false;
    }
    function adminSwitchStrategy(bool _switch) public onlyOwner{
        usingStrategy = _switch;
    }
    function adminChangeStrategyFactors(bool _st,uint256 factor_,uint256 split_,address vault_) public onlyOwner{
        require(burnSplit<=FACTOR_BASE,"check uppass");
        usingStrategy = _st;
        factor = factor_;
        burnSplit = split_;
        rewardVault = vault_;
    }

    function adminAddFromWhiteList(address white)public onlyOwner{
        if (!fromWhitelist.contains(white)){
            fromWhitelist.add(white);
        }
    }
    function adminDelFromWhiteList(address white)public onlyOwner{
        if (fromWhitelist.contains(white)){
            fromWhitelist.remove(white);
        }
    }
    function adminAddTestList(address white)public onlyOwner{
        if (!testList.contains(white)){
            testList.add(white);
        }
    }
    function adminDelTestList(address white)public onlyOwner{
        if (testList.contains(white)){
            testList.remove(white);
        }
    }
    function adminAddToWhiteList(address white)public onlyOwner{
        if (!toWhitelist.contains(white)){
            toWhitelist.add(white);
        }
    }
    function adminDelToWhiteList(address white)public onlyOwner{
        if (toWhitelist.contains(white)){
            toWhitelist.remove(white);
        }
    }
    function adminAddSwapPair(address pair)public onlyOwner{
        if (!swapPairs.contains(pair)){
            swapPairs.add(pair);
        }
    }
    function adminRemoveSwapPair(address pair)public onlyOwner{
        if (swapPairs.contains(pair)){
            swapPairs.remove(pair);
        }
    }
    
    function restorativeRebase(uint256 epoch,int256 supplyDelta) external
        onlyMonetaryPolicy onlyAfterRebaseStart nonReentrant returns(uint256){
        uint256 totalSupply = totalSupply();
        logs.push(
            RebaseLog({
                epoch:epoch,
                time:block.timestamp,
                initTotal:totalSupply,
                supplyDelta:supplyDelta,
                absDelta:uint256(supplyDelta.abs()),
                burned:0,
                rewards:0
            })
        );
        emit LogRebase(epoch, totalSupply);
        return totalSupply;
    }

    function _inTestList(address account) public view returns(bool){
        return testList.contains(account);
    }

    function _inFromWhiteList(address account)public view returns(bool){
        return ( fromWhitelist.contains(account) || account == rewardVault || account==address(0) );
    }
    function _inToWhiteList(address account)public view returns(bool){
        return ( toWhitelist.contains(account) || account == rewardVault || account==address(0) );
    }
    function _inSwapPair(address account)public view  returns(bool){
        return swapPairs.contains(account);
    }

    function viewTryBurnTransfer(address account,address to,uint256 amount)virtual public view returns(bool,uint256,uint256);    
}