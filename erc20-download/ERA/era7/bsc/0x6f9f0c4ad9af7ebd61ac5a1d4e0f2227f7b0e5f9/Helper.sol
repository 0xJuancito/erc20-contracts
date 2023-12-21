// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Ownable.sol";
import "./ReentrancyGuard.sol";

contract Helper is Ownable,ReentrancyGuard {

  address[] public helpers;
  mapping(address => uint) helperIndexs;

  bool public pause;

  constructor(){
    pause = false;
  }

  function addHelper(address helper) external onlyOwner {
    require(helper != address(0),"Helper:set helper error");
    uint index = helperIndexs[helper];
    if(index == 0){
      helpers.push(helper);
      helperIndexs[helper] = helpers.length;
    }
  }

  function removeHelper(address helper) external onlyOwner{
    uint index = helperIndexs[helper];
    require(index > 0,"Helper:remove helper error");
    if(helpers.length != index){
        address old = helpers[helpers.length - 1];
        helpers[index - 1] = old;
        helperIndexs[old] = index;
      }
      helpers.pop();
      delete helperIndexs[helper];
  }

  function pauseContract() external onlyHelper{
    pause = true;
  }

  function resume() external onlyHelper{
    pause = false;
  }

  modifier onlyHelper() {
    require(helperIndexs[_msgSender()] > 0 || owner() == _msgSender(), "Helper: caller is not the helper");
    _;
  }

  modifier isPause() {
    require(!pause, "Helper: contract is paused");
    _;
  }

}
