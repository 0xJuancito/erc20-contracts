// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import '@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol';
import './BEP20.sol';
import './TokenRecover.sol';

contract POP is Ownable, BEP20("POP Network Token", "POP"), TokenRecover {
    
    address public minter;
    uint public constant MAX_SUPPLY = 1600000000 * (10 ** 18);

    event SetMinter(address minter);

    constructor() public { 
        minter = msg.sender;   
    }

    function setMinter(address _minter) public onlyOwner {
        minter = _minter;
        emit SetMinter(_minter);
    }

    function mint(address _to, uint256 _amount) public {
        require(minter == msg.sender, "POP: caller is not a minter");
        require(_amount.add(totalSupply()) <= MAX_SUPPLY, "POP: maxcap reached");
        _mint(_to, _amount);
    }

    function burn(uint256 _amount) public {
        _burn(_msgSender(), _amount);
    }

}