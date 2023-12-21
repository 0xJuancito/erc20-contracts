// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "./token/ERC20.sol";
import "./utils/Ownable.sol";

contract SimpliToken is ERC20("Simpli Finance Token", "SIMPLI"), Ownable {
    uint256 private immutable _cap;

    constructor (uint256 cap) public {
        _cap = cap;
    }

    function cap() public view virtual returns (uint256) {
        return _cap;
    }

    function mint(address _to, uint256 _amount) public onlyOwner {
        require(totalSupply() + _amount <= cap(), "Cannot mint more than cap");
        _mint(_to, _amount);
    }
}
