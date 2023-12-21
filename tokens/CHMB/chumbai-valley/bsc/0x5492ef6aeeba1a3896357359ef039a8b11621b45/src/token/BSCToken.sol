// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BSCToken is ERC20("Chumbi Valley", "CHMB"), Ownable {
    constructor(address beneficiary) {
        require(
            beneficiary != address(0),
            "beneficiary cannot be the 0 address"
        );
        uint256 supply = 30000000000 ether;
        _mint(beneficiary, supply);
    }

    function getOwner() external view returns (address) {
        return owner();
    }
}
