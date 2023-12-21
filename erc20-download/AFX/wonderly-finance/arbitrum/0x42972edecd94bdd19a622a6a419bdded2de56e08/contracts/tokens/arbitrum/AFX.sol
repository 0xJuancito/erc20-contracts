// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "../YToken.sol";

contract AFX is YToken {
    uint256 public constant MAX_TOTAL_SUPPLY = 30_000_000 ether;

    constructor(
        string memory _name,
        string memory _symbol,
        address _daoFund,
        address _devFund,
        address _treasuryFund,
        address _reserve
    ) YToken(_name, _symbol) {
        _mint(msg.sender, 100 ether);
        _mint(_daoFund, 3_000_000 ether); // 10%
        _mint(_devFund, 3_000_000 ether); // 10%
        _mint(_treasuryFund, 3_000_000 ether); // 10%
        _mint(_reserve, MAX_TOTAL_SUPPLY - 9_000_100 ether); // Includes the 100 minted at genesis.
    }

    // ===== OVERRIDEN =============

    function maxTotalSupply() internal pure override returns (uint256) {
        return MAX_TOTAL_SUPPLY;
    }
}
