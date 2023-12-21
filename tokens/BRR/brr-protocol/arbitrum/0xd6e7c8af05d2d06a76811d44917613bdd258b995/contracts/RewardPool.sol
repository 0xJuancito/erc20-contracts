pragma solidity ^0.8.0;

import "./Operator.sol";
import "./Brr.sol";

contract RewardPool is Operator{

    Brr private _brr;
    
    event EmitRewards(
        address user,
        uint amount
    );

    constructor(address brr){
        _brr = Brr(brr);
    }

    function emitRewards(address user, uint amount) external onlyOperator{
        require(amount > 0, "Amount must be greater than 0");
        require(user != address(0), "User address must be different than 0");
        require(_brr.balanceOf(address(this)) >= amount, "Not enough BRR in pool");
        _brr.transfer(user, amount);
        emit EmitRewards(user, amount);
    }
}