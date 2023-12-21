pragma solidity ^0.5.0;

import "./ERC20Detailed.sol";
import "./Context.sol";
import "./ERC20.sol";
import "./LGEWhitelisted.sol";

contract KEL is Context, ERC20, ERC20Detailed, LGEWhitelisted {
    constructor () public ERC20Detailed("KelVPN token", "KEL", 18) {
        _mint(_msgSender(), 100000000000000000000000000 );
    }
    
    function _transfer(address sender, address recipient, uint256 amount) internal {
        _applyLGEWhitelist(sender, recipient, amount);
        super._transfer(sender, recipient, amount);
    }
}