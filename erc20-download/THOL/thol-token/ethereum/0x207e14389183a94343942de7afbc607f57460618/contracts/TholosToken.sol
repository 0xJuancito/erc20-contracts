// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/**************************************

    security-contact:
    - security@angelblock.io

    maintainers:
    - marcin@angelblock.io
    - piotr@angelblock.io
    - mikolaj@angelblock.io
    - sebastian@angelblock.io

    contributors:
    - domenico@angelblock.io

**************************************/

// OpenZeppelin imports
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**************************************

    Tholos token: THOL

 **************************************/

contract TholosToken is ERC20 {

    /**************************************
        
        ** Constructor **

        ------------------------------

        @param alloc Address of VestedAlloc contract
        @param amount Total supply of $THOL
    
    **************************************/

    constructor(
        address alloc,
        uint256 amount
    )
    ERC20("Tholos", "THOL") {

        // mint tokens to allocation contract
        _mint(alloc, amount);

    }

}
