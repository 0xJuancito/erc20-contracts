// SPDX-License-Identifier: MIT
pragma solidity ^0.8;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract iNFTspaceToken is ERC20, Ownable {
    constructor(string memory name, string memory symbol, address issuer, uint256 supply) ERC20(name, symbol) {
        _mint(issuer, supply);
    }

    function batchTransfer(address[] memory _accounts, uint256[] memory _amounts) public {
        for(uint256 i = 0; i < _accounts.length; i++){
            super.transfer(_accounts[i], _amounts[i]);
        }
    }

    function batchBalanceOf(address[] memory _accounts) public view returns(uint256[] memory) {
        uint256[] memory batchBalances = new uint256[](_accounts.length);
        for(uint256 i = 0; i < _accounts.length; i++){
            batchBalances[i] = super.balanceOf(_accounts[i]);
        }
        return batchBalances;
    }
}