pragma solidity 0.8.17;

// SPDX-License-Identifier: MIT

// MGP - MOST Global Ecosystem Utility Token

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract MGPToken is ERC20, ERC20Burnable {

    // Mint is Stoppable
    bool public mintStopped = false;
    address public minterAddress;

    constructor(string memory name, string memory symbol, address _minterAddress) ERC20(name, symbol) {
        minterAddress = _minterAddress;
    }

    function mint(address to, uint256 amount) public {
        require(msg.sender == minterAddress, "Not a minter");
        require(mintStopped != true, "Mint stopped");
        _mint(to, amount);
    }

    function stopMint() public {
        require(msg.sender == minterAddress, "Not a minter");
        mintStopped = true;
    }

}