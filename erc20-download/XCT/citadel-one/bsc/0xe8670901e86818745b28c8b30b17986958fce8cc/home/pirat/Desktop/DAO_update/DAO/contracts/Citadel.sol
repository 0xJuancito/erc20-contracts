// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.6.2;
pragma experimental ABIEncoderV2;


import "./Token/CitadelTokenLocker.sol";


contract Citadel is CitadelTokenLocker {

    constructor ()
    public {
        // mint inflation
        uint inflation = uint(500000000).mul(1e6);
        _mint(address(1), inflation);

        _initInflation(inflation, inflation, 800, 40);

        _initCitadelTokenLocker(address(2));

        _mint(address(this), uint(500000000).mul(1e6));
    }

    function delegateTokens (address to, uint amount) external onlyOwner {
        _transfer(address(this), to, amount);
    }

}
