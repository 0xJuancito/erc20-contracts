/*
DigiBunnies 
*/

// SPDX-License-Identifier: No License

pragma solidity 0.8.7;

import "./ERC20.sol";
import "./ERC20Burnable.sol";
import "./Ownable.sol"; 

contract DigiBunnies is ERC20, ERC20Burnable, Ownable {
      
    constructor()
        ERC20("DigiBunnies", "DGBN") 
    {
        address supplyRecipient = 0x595e67ecbb265020b1a8587bEE727470c741Df9A;
        
        _mint(supplyRecipient, 1000000000000 * (10 ** decimals()));
        _transferOwnership(0x595e67ecbb265020b1a8587bEE727470c741Df9A);
    }

    receive() external payable {}

    function decimals() public pure override returns (uint8) {
        return 18;
    }
    
    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override
    {
        super._afterTokenTransfer(from, to, amount);
    }
}
