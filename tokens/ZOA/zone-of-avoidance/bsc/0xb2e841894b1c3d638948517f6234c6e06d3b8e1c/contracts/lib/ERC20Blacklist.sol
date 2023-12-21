// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract ERC20Blacklist is ERC20, Ownable {
    mapping(address => bool) private blacklisted;

    event Blacklisted(address indexed account, address indexed owner);
    event UnBlacklisted(address indexed account, address indexed owner);

    function isBlacklisted(address account) public view returns(bool) {
        return blacklisted[account];
    }

    function blacklist(address account) external onlyOwner returns(bool) {
        require(account != address(0), "ERC20Blacklist: blacklisted zero address");
        require(account != owner(), "ERC20Blacklist: blacklisted owner");
        require(!blacklisted[account], "ERC20Blacklist: already blacklisted");
        blacklisted[account] = true;
        emit Blacklisted(account, _msgSender());
        return true;
    }

    function unBlacklist(address account) external onlyOwner returns(bool) {
        require(blacklisted[account], "ERC20Blacklist: not yet blacklisted");
        blacklisted[account] = false;
        emit UnBlacklisted(account, _msgSender());
        return true;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        if (_msgSender() != owner()) {
            require((!isBlacklisted(from)) && (!isBlacklisted(to)), "ERC20Blacklist: account is blacklisted");
        }
    }

}