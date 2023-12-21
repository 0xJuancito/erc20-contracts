// SPDX-License-Identifier: ISC

pragma solidity 0.8.9;

contract RewardFeeProvider {
   function getClaimFee(uint256 lastClaimTime) public view returns(uint256) {
        return (block.timestamp - lastClaimTime) / 1 days;
   }

   function caculateClaimFee(uint256 lastClaimTime, uint256 amount) public view returns(uint256) {
       return (getClaimFee(lastClaimTime) * amount) / 100;
   }
}
