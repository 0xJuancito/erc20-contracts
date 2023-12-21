// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

import "./ERC20.sol";

contract SKPERC20 is ERC20 {

    constructor() ERC20("SKY PLAY", "SKP"){
        _mint(_msgSender(), 1e10 * (10 ** uint256(decimals())));
    }

    /**
     * @dev Prevention of deposit errors
     */
    function deposit() payable public {
        require(msg.value == 0, "Cannot deposit ether.");
    }
}
