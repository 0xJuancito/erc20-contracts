// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";




contract TALToken is ERC20, ERC20Burnable {
    
    constructor() ERC20("TALKI", "TAL") {
        _mint(
            0x5E6308052129B42A07dd2550500e767B7f9351Dc,
            2000000000 * (10**uint256(decimals()))
        );
        
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    
}
