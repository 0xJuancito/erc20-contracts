// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./contracts/token/ERC20/ERC20.sol";
import "./contracts/access/Ownable.sol";

/**
 * COSMIC token
 * @author COSMIC
 */
contract Cosmic is ERC20, Ownable {
    constructor() ERC20("COSMIC FOMO", "COSMIC") {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function burn(uint256 amount) public virtual {
        address owner = _msgSender();
        _burn(owner, amount);
    }
}
