// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ERC20.sol";

contract OmoToken is ERC20 {
    using SafeMath for uint256;
    uint256 public constant MAX_TOTAL_SUPPLY = 250_000_000e18;

    constructor(uint256 _initialSupply) ERC20("OMO Token", "OMO") {
        _mint(msg.sender, _initialSupply);
    }

    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (MasterChef).
    function mint(address _to, uint256 _amount) public onlyOwner {
        require(
            _amount + totalSupply() <= MAX_TOTAL_SUPPLY,
            "OmoToken: Max total supply exceeded"
        );
        _mint(_to, _amount);
    }

    // Safe omo transfer function
    function safeOmoTransfer(address _to, uint256 _amount) public onlyOwner {
        uint256 omoBal = balanceOf(address(this));
        if (_amount > omoBal) {
            _transfer(address(this), _to, omoBal);
        } else {
            _transfer(address(this), _to, _amount);
        }
    }
}