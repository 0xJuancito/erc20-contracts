// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @author Lumishare
 *
 * @notice Main contract that has the logic of the presale
 */
contract LumiShare is ERC20 {
    uint256 public constant MAX_SUPPLY = 7951696555 ether;

    constructor(address multiSigWallet) ERC20("LumiShare", "LUMI") {
        // everything will be minted here
        _mint(multiSigWallet, MAX_SUPPLY);
    }



}
