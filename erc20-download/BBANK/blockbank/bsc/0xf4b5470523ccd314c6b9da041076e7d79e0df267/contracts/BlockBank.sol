// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import './BEP20.sol';
import './LGEWhitelisted.sol';

contract BlockBank is Ownable, BEP20("BlockBank", "BBANK"), LGEWhitelisted {
    
    uint public constant TOTAL_SUPPLY = 400000000 * (10 ** 18);
    
    constructor() public {    
        _mint(msg.sender, TOTAL_SUPPLY);
    }
    
    function _transfer(address sender, address recipient, uint256 amount) internal override {
        LGEWhitelisted._applyLGEWhitelist(sender, recipient, amount);
        super._transfer(sender, recipient, amount);
    }
}
