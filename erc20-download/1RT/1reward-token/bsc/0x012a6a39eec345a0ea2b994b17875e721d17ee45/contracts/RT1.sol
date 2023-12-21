// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RT1 is ERC20, Ownable {

    bool public mintOneTime;
    constructor() ERC20("1move", "1RT") {
        mintOneTime = false;
    }

    function mint(address _account) external onlyOwner {
        require(mintOneTime == false, "Already mint to the main address");
         _mint(_account, 2100000000*10**decimals());
         mintOneTime = true;
    }


}