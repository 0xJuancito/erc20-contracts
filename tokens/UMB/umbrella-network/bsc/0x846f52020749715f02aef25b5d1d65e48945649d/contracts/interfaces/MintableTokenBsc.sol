//SPDX-License-Identifier: MIT
pragma solidity 0.7.5;

// Inheritance
import "../interfaces/MintableToken.sol";

abstract contract MintableTokenBsc is MintableToken {
    address public bridge;

    event LogUpdateBridge(address prevBridge, address newBridge);

    modifier onlyBridge() {
        require(bridge == msg.sender, "only bridge can mint");
        _;
    }

    constructor (uint256 _maxAllowedTotalSupply) MintableToken(_maxAllowedTotalSupply) {
    }

    // ========== RESTRICTED FUNCTIONS ========== //

    function updateBridge(address _bridge) external onlyOwner() {
        require(_bridge != address(0), "empty bridge address");
        emit LogUpdateBridge(bridge, _bridge);
        bridge = _bridge;
    }

    function mint(address _holder, uint256 _amount) override external onlyBridge() assertMaxSupply(_amount) {
        require(_amount > 0, "zero amount");
        _mint(_holder, _amount);
    }
}
