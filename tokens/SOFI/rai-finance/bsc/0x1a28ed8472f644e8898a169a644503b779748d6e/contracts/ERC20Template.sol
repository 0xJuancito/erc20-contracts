pragma solidity ^0.5.0;

import "./Context.sol";
import "./ERC20.sol";
import "./ERC20Detailed.sol";

contract ERC20Template is Context, ERC20, ERC20Detailed {
    
    constructor () public ERC20Detailed("Rai.Finance", "SOFI", 18) {
        _mint(_msgSender(), 1000000000000000000000000000);
    }
}