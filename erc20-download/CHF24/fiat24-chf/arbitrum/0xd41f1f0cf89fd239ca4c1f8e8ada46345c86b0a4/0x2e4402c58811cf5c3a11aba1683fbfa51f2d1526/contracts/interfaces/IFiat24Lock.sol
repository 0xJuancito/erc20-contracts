// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


interface IFiat24Lock {
    function lock(uint256 tokenId_, address currency_, uint256 amount_) external; 
    function claim(address currency_, uint256 amount_) external;
}