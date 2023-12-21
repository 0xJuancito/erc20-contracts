// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./AIToken.sol";
import "./Ownable.sol";

contract AITokenFactory is Ownable {
    
    uint256 public deploymentFee;
    address[] public deployedTokens;
    event TokenDeployed(address indexed tokenAddress, address indexed owner);

    constructor(uint256 _deploymentFee) Ownable(msg.sender) {
        deploymentFee = _deploymentFee;
    }

    receive() external payable {}

    function setDeploymentFee(uint256 _newFee) external onlyOwner {
        deploymentFee = _newFee;
    }

    function createToken(string memory _name, string memory _symbol, uint _initialSupply) public payable returns (address) {
        require(msg.value == deploymentFee, "Insufficient fee in ETH");
        AIToken newToken = new AIToken(); // No arguments passed to AIToken constructor
        newToken.initialize(_name, _symbol, _initialSupply, msg.sender);
        deployedTokens.push(address(newToken));
        emit TokenDeployed(address(newToken), msg.sender);
        return address(newToken);
    }

    function getDeployedTokens() external view returns (address[] memory) {
        return deployedTokens;
    }

    function withdrawFees(address payable to) external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        to.transfer(balance);
    }

}