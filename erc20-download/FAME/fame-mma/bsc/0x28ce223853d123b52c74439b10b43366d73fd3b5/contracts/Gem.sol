//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.10;

import "./BEP20.sol";
import "./Admin.sol";

contract Gem is BEP20, Admin {
    mapping(address => bool) public isWhitelisted;

    constructor(
        string memory _name,
        string memory _short,
        uint256 _totalSupply
    ) BEP20(_name, _short, _totalSupply) {
        locked = true;
    }

    function clearLocked() public onlyOwner {
        locked = false;
    }

    function setWhitelisted(address whitelisted) public onlyAdmin {
        isWhitelisted[whitelisted] = true;
    }

    function removeWhitelisted(address whitelisted) public onlyAdmin {
        require(isWhitelisted[whitelisted], "not-whitelisted");
        isWhitelisted[whitelisted] = false;
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        require(!locked || isAdmin[_msgSender()] || isWhitelisted[_msgSender()], "transfers-locked");
        return BEP20.transfer(to, amount);
    }
}
