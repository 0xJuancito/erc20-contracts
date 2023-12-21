pragma solidity ^0.8.17;


// SPDX-License-Identifier: MIT

/***************************************************************************/
// YOU are more than your eyeballs. 
// Youcoin brings you a more human internet with global proof-of-personhood. 

// Privacy-first, self-custodial, decentralized.

// More details coming soon at youcoin.org

// #YOUIzBetter
/***************************************************************************/


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Youcoin is ERC20, Ownable {
    constructor() ERC20("Youcoin", "YOU") {
        ERC20._mint(msg.sender, 1000000000 ether);
    }
}