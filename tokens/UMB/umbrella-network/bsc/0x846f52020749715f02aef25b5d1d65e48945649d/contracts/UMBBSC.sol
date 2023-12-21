//SPDX-License-Identifier: MIT
pragma solidity 0.7.5;

// Inheritance
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./interfaces/MintableTokenBsc.sol";
import "./interfaces/Airdrop.sol";
import "./interfaces/Payable.sol";


contract UMBBSC is MintableTokenBsc, Airdrop, Payable {
    // ========== EVENTS ========== //

    event LogSetRewardTokens(address[] tokens, bool[] statuses);

    // ========== CONSTRUCTOR ========== //

    constructor (
        address _owner,
        address _initialHolder,
        uint _initialBalance,
        uint256 _maxAllowedTotalSupply,
        string memory _name,
        string memory _symbol
    )
    Owned(_owner)
    ERC20(_name, _symbol)
    MintableTokenBsc(_maxAllowedTotalSupply) {
        if (_initialHolder != address(0) && _initialBalance != 0) {
            _mint(_initialHolder, _initialBalance);
        }
    }
}
