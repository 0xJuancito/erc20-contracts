// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./interfaces/ERC20.sol";

contract VitnixX is ERC20("VitnixX", "VTC", 18) {
    function initialMint(address _recv) external onlyOwner {
        _mint(_recv, this.maxSupply());
    }
}
