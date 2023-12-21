// SPDX-License-Identifier: AGPL

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title   DSquared Governance Token
 * @notice  Mintable/burnable ERC-20 token with cap on cumulative amount which can be minted
 * @author  HessianX
 * @custom:developer  BowTiedOriole
 * @custom:developer  BowTiedPickle
 */
contract DSQToken is ERC20, ERC20Burnable, Ownable {
    uint256 public constant MAX_SUPPLY = 500000 ether;
    uint256 public totalMinted;

    /**
     * @param   _owner          Owner address
     * @param   _initialSupply  Initial token supply
     */
    constructor(address _owner, uint256 _initialSupply) ERC20("DSquared Governance Token", "DSQ") {
        require(_owner != address(0), "Param");
        require(_initialSupply <= MAX_SUPPLY, "Param");
        _transferOwnership(_owner);
        totalMinted += _initialSupply;
        _mint(_owner, _initialSupply);
    }

    /**
     * @notice  Permissioned mint to owner
     * @param   _amount     Amount of token to mint
     */
    function mint(uint256 _amount) external onlyOwner {
        require(totalMinted + _amount <= MAX_SUPPLY, "Max supply reached");
        totalMinted += _amount;
        _mint(owner(), _amount);
    }
}
