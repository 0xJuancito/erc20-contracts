// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract NuNetUpgradeableTokenV2 is Initializable, OwnableUpgradeable, ERC20Upgradeable {
    
    /**
    * @dev Function to initialize the token contract with name, symbol and owner.
    * And mints the initial supply and transfers to the owner
    */
    function initialize(string memory name, string memory symbol, uint256 initialSupply) public virtual initializer {
        __ERC20_init(name, symbol);
        __Ownable_init();
        _mint(_msgSender(), initialSupply);
    }

    /**
    * @dev Function to override the default decimals and should be available 
    * for future upgrades to avoid default 18 decimals.
    */
    function decimals() public pure virtual override returns (uint8) {
        return 6;
    }

    /**
    * @dev Function to burn the tokens.
    */
    function burn(uint256 amount) external onlyOwner {

     	require (amount > 0,"Invalid amount");
        _burn(_msgSender(), amount);
        
    }

}