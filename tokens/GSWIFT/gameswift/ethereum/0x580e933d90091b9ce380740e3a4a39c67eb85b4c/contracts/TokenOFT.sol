// SPDX-License-Identifier: LIC
pragma solidity 0.8.18;

import "@layerzerolabs/solidity-examples/contracts/token/oft/OFT.sol";

contract TokenOFT is OFT {
    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint
    ) OFT(_name, _symbol, _lzEndpoint) {}
}
