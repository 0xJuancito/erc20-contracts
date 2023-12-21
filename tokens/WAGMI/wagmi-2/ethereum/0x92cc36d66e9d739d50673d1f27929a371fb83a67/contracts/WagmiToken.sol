// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@layerzerolabs/solidity-examples/contracts/token/oft/extension/GlobalCappedOFT.sol";

/**
 * @notice Use this contract only on the BASE CHAIN. It locks tokens on source, on outgoing send(), and unlocks tokens when receiving from other chains.
 */
contract WagmiToken is GlobalCappedOFT {
    uint256 public constant GLOBAL_MAX_TOTAL_SUPPLY = 4_761_000_000 ether;

    constructor(
        address _lzEndpoint
    ) GlobalCappedOFT("Wagmi", "WAGMI", GLOBAL_MAX_TOTAL_SUPPLY, _lzEndpoint) {}

    function mint(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
    }
}
