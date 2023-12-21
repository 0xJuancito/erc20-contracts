// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;

import "./PlainElasticTokenWBase.sol";
import "../../../interfaces/IESTPolicy.sol";
contract PlainElasticTokenWFixedRate is PlainElasticTokenWBase{
    using SafeMathInt for int256;
    using SafeMathUpgradeable for uint256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    function __rebaseBurn(address account,uint256 amount) internal view returns(bool,uint256,uint256){
        uint256 toBeLocked = amount.mul(factor).div(FACTOR_BASE);
        uint256 balance = balanceOf(account);
        bool pass = true;
        if (balance < toBeLocked.add(amount)){
            pass = false;
        }
        uint256 toBeBurned = toBeLocked.mul(burnSplit).div(FACTOR_BASE);
        uint256 tobeRewarded = toBeLocked.sub(toBeBurned);
        return (pass,toBeBurned,tobeRewarded);
    }

    function viewTryBurnTransfer(address account,address to,uint256 amount)public override  view returns(bool,uint256,uint256){
        if (account == to) return (true,0,0);
        if (!usingStrategy) return(true,0,0);
        if (_inFromWhiteList(account) || _inToWhiteList(to)){
            return (true,0,0);
        }
        bool needBurn = false;
        if (logs.length>0){
            uint256 index = logs.length-1;
            RebaseLog memory lastLog = logs[index];
            if (lastLog.supplyDelta<0){
                needBurn = true;
                
            }
        }
        if (needBurn || _inTestList(account) ){
            if (_inSwapPair(account)){
                //transfer from swap,means remove liquidity or buy from swap
                return (true,0,0);
            }else{
                //others burn
                return __rebaseBurn(tx.origin, amount);
            }
        }
        return (true,0,0);
    }

    function __expandBeforeTokenTransfer(address account, address to, uint256 amount) internal override virtual {
        if (account == to) return;
        if (!usingStrategy) return;
        if (_inFromWhiteList(account) || _inToWhiteList(to)){
            return;
        }
        bool needBurn = false;
        uint256 index=0;
        if (logs.length>0){
            index = logs.length-1;
            RebaseLog memory lastLog = logs[index];
            if (lastLog.supplyDelta<0){
                needBurn = true;
            }else if (monetaryPolicy!=address(0)){
                (uint256 price,uint256 target,) = IESTPolicy(monetaryPolicy).getRebaseValues();
                if (price<target){
                    needBurn = true;
                }
            }
        }
        if (needBurn || _inTestList(account) ){
            if (_inSwapPair(account)){
                //transfer from swap,means remove liquidity or buy from swap
                return;
                //use tx.origin ignore why he made this happen, just give prize to the initiator not the msg sender
                // if (rewardVault!=address(0)){
                //     PlainIRewardVault(rewardVault).noticeUnderWaterBuy(index,tx.origin,amount);
                // }
            }else{
                //others burn and add mining rewards when above water
                //use tx.origin ignore why he made this happen, just punish the initiator not the msg sender
                uint256 toBeLocked = amount.mul(factor).div(FACTOR_BASE);
                if (rewardVault==address(0)){
                    __expandBurn(tx.origin,toBeLocked);
                    totalBurned = totalBurned.add(toBeLocked);
                    logs[index].burned = logs[index].burned.add(toBeLocked);
                    return;
                }
                uint256 toBeBurned = toBeLocked.mul(burnSplit).div(FACTOR_BASE);
                uint256 tobeRewarded = toBeLocked.sub(toBeBurned);
                __expandBurn(tx.origin, toBeBurned);
                totalBurned = totalBurned.add(toBeBurned);
                __expandTransferDirect(tx.origin,rewardVault,tobeRewarded);
                
                logs[index].burned = logs[index].burned.add(toBeBurned);
                logs[index].rewards = logs[index].rewards.add(tobeRewarded);
            }
        }
    }

}