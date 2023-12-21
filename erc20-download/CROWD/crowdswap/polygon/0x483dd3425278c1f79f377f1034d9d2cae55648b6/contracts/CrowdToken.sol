// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract CrowdToken is ERC20Burnable {

    address public distributionContractAddress;
    
    constructor(string memory name, string memory symbol, uint256 initialSupply, address _distributionContractAddress) ERC20(name, symbol) {
        _mint(_distributionContractAddress, initialSupply);
        distributionContractAddress = _distributionContractAddress;
    }
}
