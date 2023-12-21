// SPDX-License-Identifier: ISC

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IFundProcessor.sol";
import "hardhat/console.sol";

contract TeamFaucet is Ownable {
    address[3] addresses;

    uint256 public totalMinted;
    uint256 public lastSendTimestamp;
    uint256 public maxMintPerDay = 120_000 * 10 ** 18;

    ERC20PresetMinterPauser hedgePay;

    constructor(
        address _hedgePay,
        address _addr1,
        address _addr2,
        address _addr3
    ) {
        hedgePay = ERC20PresetMinterPauser(_hedgePay);
        addresses[0] = _addr1;
        addresses[1] = _addr2;
        addresses[2] = _addr3;
        lastSendTimestamp = block.timestamp;
    }


    function distribute() public {  
        uint256 daysSinceLastMint = (block.timestamp - lastSendTimestamp) / 1 days;
        require(daysSinceLastMint >= 1 , "Wait at least one day for new rewards");
        uint256 rewardCap = (hedgePay.totalSupply() * 3) / 100;
        require(totalMinted < rewardCap, "Reward exceeds supply cap"); 
        uint256 toBeMinted  = daysSinceLastMint * maxMintPerDay;
        
        require(toBeMinted > 0, "Nothing to be minted");
        uint256 rewardShare = toBeMinted / 3;


        if (
            addresses[0] == address(0) ||
            addresses[1] == address(0) ||
            addresses[2] == address(0)
        ) {
            return;
        }
        if (rewardShare > 0) {
            hedgePay.mint(addresses[0], rewardShare);
            hedgePay.mint(addresses[1], rewardShare);
            hedgePay.mint(addresses[2], rewardShare);

            lastSendTimestamp =  block.timestamp;
        }
    }

    function setAddress(uint256 index, address newAddress) external onlyOwner  {
        require(address(0) != newAddress, "Address cannot be 0");
        addresses[index] = newAddress;
    }

    function getAddress(uint256 index) external view onlyOwner returns(address)  {
        return addresses[index];
    }
}
