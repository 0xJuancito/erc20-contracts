// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract KingOfLegends is ERC20, Pausable, Ownable {
    event AddedBlackList(address _user);

    event RemovedBlackList(address _user);

     mapping (address => bool) public isBlackListed;

    constructor() ERC20("KingOfLegends", "KOL") {
        _mint(msg.sender, 1000000000 * 10 ** decimals());
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
    function addBlackList (address _evilUser) public onlyOwner {
        isBlackListed[_evilUser] = true;
        emit AddedBlackList(_evilUser);
    }

    function removeBlackList (address _clearedUser) public onlyOwner {
        isBlackListed[_clearedUser] = false;
        emit  RemovedBlackList(_clearedUser);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
         require(!isBlackListed[from],"KOL: Transfer from blacklist!");
        super._beforeTokenTransfer(from, to, amount);
    }
}