// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SRX is ERC20, Ownable {
    constructor() ERC20("Stars", "SRX") {}
    
    address public stakingAddress;
    
    uint public maxSupply = 27000000 * 10 ** decimals();

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function mintStaking(address to, uint256 amount) public  {
        require(msg.sender == stakingAddress);
        require(totalSupply() <= maxSupply);
        _mint(to, amount);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function setStakingAddress(address _address) public onlyOwner {
        stakingAddress = _address;
    }

    function setMaxSupply(uint _maxSupply) public onlyOwner {
        maxSupply = _maxSupply;
    }

}