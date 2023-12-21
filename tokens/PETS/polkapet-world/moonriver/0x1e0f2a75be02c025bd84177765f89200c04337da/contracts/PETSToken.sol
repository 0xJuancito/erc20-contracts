// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// ERC-20 Token with 2% yearly inflation (compounding), distributed quarterly

contract PETSToken is ERC20, Ownable {
    uint256 public initialCap = 100000000 ether;
    uint256 public tgeAt = 1635422400; // 10-28-2021 12:00:00 UTC

    // unsigned 16.112-bit fixed point number
    // (1.02) ^ (1/4) << 112 = 5218065872551496750682311808311216
    uint128 private quarterlyInterestRate = 0x10145402ccc981a95f01c22a0dfb0;

    constructor () ERC20("PETS Token", "PETS") {
        super._mint(msg.sender, initialCap);
        transferOwnership(0x1F6A5BD6BF72F0b7D7c6379E4a9116FD19856A9e); 
    }

    function availableTotalSupply() external view returns(uint256){
        return _availableTotalSupply();
    }
    
    function availableToMint() external view returns(uint256){
        return _availableToMint();
    }

    function _availableTotalSupply() internal view returns(uint256){
        if(block.timestamp < tgeAt){
            return initialCap;
        }
        // 90 days = 7776000 seconds
        uint256 quartersSinceTGE = (block.timestamp - tgeAt) / 7776000;
        return (initialCap * pow(quarterlyInterestRate,quartersSinceTGE)) >> 112;
    }

    function _availableToMint() internal view returns(uint256){
        return _availableTotalSupply() - totalSupply();
    }
    
    function mint(address account, uint256 amount) external onlyOwner {
        require(amount <= _availableToMint(), "Cap exceeded");
        super._mint(account,amount);
    }

    // Raises the 16.112-bit unsigned fixed point number base to the specified 256-bit unsigned integer power
    // Returns a 16.112-bit unsigned fixed point number
    function pow(uint128 base, uint256 power) internal pure returns (uint256){
        uint256 result = 0x10000000000000000000000000000; // 1 in 16.112-bit unsigned fixed point format
        uint256 x = base;
        while(power != 0){
            if(power & 0x1 != 0){
                result = (result * x) >> 112;
            }
            x = (x * x) >> 112;
            power >>=1;
        }
        return result;
    }
}