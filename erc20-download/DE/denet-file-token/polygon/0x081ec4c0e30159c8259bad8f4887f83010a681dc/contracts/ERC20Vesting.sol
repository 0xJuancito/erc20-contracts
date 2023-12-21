// SPDX-License-Identifier: MIT
/**
    * File Token Vesting.
    */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IERC20Vesting.sol";

/**
* @dev This contract is part of DeNetFileToken Contract. Issued every year from 1 
*/
contract ERC20Vesting  is IERC20Vesting, Ownable {

    address  private immutable _vestingToken;

    constructor (address _token) {
        _vestingToken = _token;
    }
    
    struct VestingProfile {
        uint64 timeStart;
        uint64 timeEnd;
        uint256 amount;
        uint256 payed;
    }
    

    mapping (address => VestingProfile) public vestingStatus;
    mapping (address => mapping(address => bool)) public allowanceVesting;
    
    // Just getter for origin token address
    function vestingToken() public view override returns(address){
        return _vestingToken;
    }
    /**
        * @notice Creating vesting for _user
        * @param _user address of reciever
        * @param timeStart timestamp of start vesting date
        * @param amount total amount of token for vesting 
        */
    function createVesting(address _user,  uint64 timeStart, uint64 timeEnd, uint256 amount) public onlyOwner {
        require(_user != address(0), "Address = 0");
        require(vestingStatus[_user].timeStart == 0, "User already have vesting");
        require(amount != 0, "Amount = 0");
        require(timeStart < timeEnd, "TimeStart > TimeEnd");
        require(timeEnd > block.timestamp, "Time end < block.timestamp");

        vestingStatus[_user] = VestingProfile(timeStart, timeEnd, amount, 0);
    }

    /**
        * @dev  Return available balance to withdraw
        * @param _user reciever address
        * @return uint256 amount of tokens available to withdraw for this moment
        */
    function getAmountToWithdraw(address _user) public view override returns(uint256) {
        VestingProfile memory _tmpProfile = vestingStatus[_user];
        
        // return 0, if user not exist. (because not possible to create zeor amount in vesting)
        if (_tmpProfile.amount == 0) {
            return 0;
        }

        if (_tmpProfile.timeStart > block.timestamp) {
            return 0;
        }
        uint _vestingPeriod = _tmpProfile.timeEnd - (_tmpProfile.timeStart);
        uint _amount = _tmpProfile.amount / (_vestingPeriod);
        if (_tmpProfile.timeEnd > block.timestamp) {
            _amount = _amount * (block.timestamp - (_tmpProfile.timeStart));
        } else {
            _amount = _tmpProfile.amount;
        }
        return _amount - (_tmpProfile.payed);
    }

    /**
        * @dev Withdraw tokens function
        */
    function _withdraw(address _user) internal {
        uint _amount = getAmountToWithdraw(_user);
        vestingStatus[_user].payed = vestingStatus[_user].payed + (_amount);

        IERC20 tok = IERC20(_vestingToken);
        require (tok.transfer(_user, _amount) == true, "ERC20Vesting._withdraw:Error with _withdraw.transfer");
        
        emit Vested(_user, _amount);
    }

    /**
        * @dev Withdraw for msg.sender
        */
    function withdraw() external override {
        _withdraw(msg.sender);
    }

    /**
        * @dev Withdraw for Approved Address
        */
    function withdrawFor(address _for) external override {
        require(allowanceVesting[_for][msg.sender], "ERC20Vesting.withdrawFor: Not Approved");
        _withdraw(_for);
    }

    /**
        * @dev Approve for withdraw for another address
        */
    function approveVesting(address _to) external override {
        allowanceVesting[msg.sender][_to] = true;
    }

    /**
        * @dev Stop approval for withdraw for another address
        */
    function stopApproveVesting(address _to) external override {
        allowanceVesting[msg.sender][_to] = false;
    }
}