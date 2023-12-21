// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {
    UpgradeableCappedMultiBridgeToken
} from "./UpgradeableCappedMultiBridgeToken.sol";

contract MultiBridgeGel is UpgradeableCappedMultiBridgeToken {
    uint256 private _gelTotalSupply;

    function initialize(
        string calldata _name,
        string calldata _symbol,
        uint256 _epochLength,
        uint256 __gelTotalSupply
    ) external initializer {
        __UpgradeableCappedMultiBridgeToken_init(_name, _symbol, _epochLength);
        _gelTotalSupply = __gelTotalSupply;
    }

    function updateTotalSupply(uint256 __gelTotalSupply)
        external
        onlyProxyAdmin
    {
        _gelTotalSupply = __gelTotalSupply;
    }

    function totalSupply() public view override returns (uint256) {
        return _gelTotalSupply;
    }
}
