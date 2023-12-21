// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// ____  _______   ____________
// \   \/  /\   \ /   /  _____/
//  \     /  \   Y   /   \  ___
//  /     \   \     /\    \_\  \
// /___/\  \   \___/  \______  /2023
//       \_/XVG              \/
//
// https://github.com/vergecurrency/erc20

contract XVG is ERC20, Ownable {

    /// @dev Creates the XVG ERC-20 token and mints the supply according to the allocations below
    constructor() ERC20("XVG ERC-20", "XVG") {
        _mint(0xF6CD14492bc882f1fe22C6590342CBFEe00Ae820, 165550000 ether); // Team 1 - 1%
        _mint(0x77036F7c220B5B86E8f3893F2670124a0b4fdB61, 165550000 ether); // Team 2 - 1%
        _mint(0xb5c768Bb97Af42890e2a2F9C860866Ba0fF5c27E, 165550000 ether); // Team 3 - 1%
        _mint(0x2eFFca7339EcCeee9943A847A98bcf9b3B94323C, 165550000 ether); // Team 4 - 1%
        _mint(0xD790C876a1806f67e5a74B8C8d34df4C96012801, 165550000 ether); // Team 5 - 1%
        _mint(0x2d2dFD493540eFc1c23c7fBaE14ddb54b5054646, 165550000 ether); // Team 6 - 1%
        _mint(0xEFE70d2e610157E104150A14467D624Cb89B5839, 165550000 ether); // Ecosystem wallet 1 XVG Currency - 1%
        _mint(0x6501277b42f5A973E241fD52B12c6Ad47B5bc23c, 2483250000 ether); // Ecosystem wallet 2 XVG Token - 15%
        _mint(0x92b8ecb313bceD208C9d428C746F9A9A38837cFC, 1655500000 ether); // Farm wallet - 10%
        _mint(0xF77a679acd5AacCaa2beAA618eA2f42336a17716, 5463150000 ether); // Pinksale wallet - 33%
        _mint(0x130bf7266031ec9c7A28C6794474D068145a7990, 2483250000 ether); // Launch wallet - 15%
        _mint(0x35668744aBdD4eeCB60faf73698edA7e4DAC8eEb, 3311000000 ether); // Burn wallet - 20%

        transferOwnership(0xc1E531c3b0599768AD9fef7cd05C397ceC15Ea14);
    }

    /// @notice Burns tokens and reduce the total supply (users can burn only amounts they own)
    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }
}
