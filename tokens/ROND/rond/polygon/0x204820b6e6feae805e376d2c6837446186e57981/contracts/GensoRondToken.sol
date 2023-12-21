// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20Capped.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GensoRondToken is ERC20Capped, Ownable {

    uint256 public constant MAX_TOTAL_SUPPLY = 1000000000000 * 10 ** 18;
    
    /**
     * @dev Initializes the contract setting.
     */
    constructor() public ERC20("ROND Coin", "ROND") ERC20Capped(MAX_TOTAL_SUPPLY) {
        _mint(msg.sender, MAX_TOTAL_SUPPLY);
    }
}
