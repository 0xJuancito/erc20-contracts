pragma solidity ^0.5.0;

import "./ERC20Detailed.sol";
import "./Context.sol";
import "./ERC20.sol";

contract MDX is Context, ERC20, ERC20Detailed {
    
    constructor (address lockProxyContractAddress) public ERC20Detailed("Poly-Peg MDX", "HMDX", 18) {
        _mint(lockProxyContractAddress, 1000000000000000000000000000);
    }
    
}