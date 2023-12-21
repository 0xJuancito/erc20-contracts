pragma solidity 0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./TokenVesting.sol";
import "./IAuroxToken.sol";

// Ignoring the 19 states declaration for simpler deployment for the Aurox guys
contract AuroxToken is IAuroxToken, ERC20, Ownable {
    TokenVesting public reservesVestingContract;
    TokenVesting public teamRewardVestingContract;

    constructor() public ERC20("Aurox Token", "URUS") {
        // Mint the supply to the deployer address
        _mint(_msgSender(), 1000000 ether);
    }

    // Expose a new function to update the allowance of a new contract
    function setAllowance(address allowanceAddress)
        external
        override
        onlyOwner
    {
        _approve(address(this), allowanceAddress, 650000 ether);

        emit SetNewContractAllowance(allowanceAddress);
    }
}
