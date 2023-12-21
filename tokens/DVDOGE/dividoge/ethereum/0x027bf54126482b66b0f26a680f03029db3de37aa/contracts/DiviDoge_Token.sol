// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/PullPayment.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DiviDoge is ERC20, PullPayment, ERC20Burnable, Ownable {

    address public contractOwner;         

    IERC20 public tokenAddress;

    uint256 public maxSupply = 1000000000*10**18;

    bool mintable = true;

    bool internal diviDogeLock;

    // Reentrancy check
    modifier diviDogeGuard()
    {
        require(!diviDogeLock);
        diviDogeLock = true;
        _;
        diviDogeLock = false;
    }
    
    modifier callerIsUser()
    {
        require(tx.origin == msg.sender, "Error: The caller is another contract");
        _;
    }

    constructor() ERC20("DiviDoge", "DVDOGE") {
        contractOwner = msg.sender;
    }


    function diviDogeUnlock() external onlyOwner callerIsUser diviDogeGuard {
        diviDogeLock = false;
    }

    function checkDiviDogeLock() public view returns (bool) {
      return diviDogeLock;
    }

    function setMintable(bool newState) external onlyOwner callerIsUser {
        mintable = newState;
    }

    function mint(address to, uint256 value) 
        public 
        onlyOwner
        callerIsUser 
        returns (bool)
    {
        require(mintable == true, "Minting is not currently Enabled");
        require(value*10**18+totalSupply() < maxSupply + 1, "Trying to mint more than the Maximum Supply");
        _mint(to, value*10**18);
        return true;
    }

    function withdrawPayments(address payable payee) public override onlyOwner diviDogeGuard callerIsUser {
        super.withdrawPayments(payee);
    }

    function setContractOwner(address _newContractOwner) public onlyOwner callerIsUser {
        contractOwner = _newContractOwner;
    }

    function withdrawPurchaseToken() public onlyOwner diviDogeGuard callerIsUser {
        tokenAddress.transfer(contractOwner, tokenAddress.balanceOf(address(this)));
    }

    function setPurchaseTokenAddress(address _newAddress) external onlyOwner callerIsUser {
        tokenAddress = IERC20(_newAddress);
    }

}