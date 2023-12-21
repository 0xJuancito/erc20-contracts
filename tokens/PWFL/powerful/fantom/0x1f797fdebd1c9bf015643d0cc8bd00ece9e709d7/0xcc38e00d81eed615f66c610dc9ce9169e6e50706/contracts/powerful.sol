//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import 'hardhat/console.sol';
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Powerful is ERC20Upgradeable, OwnableUpgradeable {

    mapping(address => bool) public blacklist;
    mapping(address => bool) public whitelist;
    
    struct userSale {
        uint256 amountAvailable;
        uint256 lastTimeSold;
    }

    mapping(address => userSale) public usersInfo;

    address pair;

    address stacking;

    function initialize() public initializer {
        __Ownable_init();
        __ERC20_init('Powerful', 'PWFL');
    }

    function mintTo(address[] memory to, uint256[] memory amount) external onlyOwner {
        for (uint256 i; i < to.length; i++) {
            _mint(to[i], amount[i]);
        }
    }

    function burnTo(address[] memory to, uint256[] memory amount) external onlyOwner {
        for (uint256 i; i < to.length; i++) {
            _burn(to[i], amount[i]);
        }
    }

    function setBlacklist(address user, bool isBlacklisted) external onlyOwner {
        blacklist[user] = isBlacklisted;
    }

    function setWhitelist(address user, bool isWhitelisted) external onlyOwner {
        whitelist[user] = isWhitelisted;
    }

    function setPair(address _pair) external onlyOwner {
        pair = _pair;
    }

    function getAvailableAmount(address sender) external view returns(uint256) {
        if (block.timestamp - usersInfo[sender].lastTimeSold >= 1 days) {
            return 1000 ether;
        }
        return usersInfo[sender].amountAvailable;
    }

    function updateAvailableAmount(address sender, uint256 amount) internal returns (bool canSell) {
        if (block.timestamp - usersInfo[sender].lastTimeSold >= 1 days || usersInfo[sender].lastTimeSold == 0) {
            usersInfo[sender].amountAvailable = 2500 ether;
            usersInfo[sender].lastTimeSold = block.timestamp;
        }

        if (amount > usersInfo[sender].amountAvailable) {
            usersInfo[sender].amountAvailable = 0;
            return false;
        } else {
            usersInfo[sender].amountAvailable = usersInfo[sender].amountAvailable - amount;
            return true;
        }        
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override virtual {
        require(blacklist[from] == false && blacklist[to] == false, 'You are blacklisted');

        if (to == pair && whitelist[from] == false) {
            require(updateAvailableAmount(from, amount), "You can't sell more than 2500 PWFL per day");
        }

        super._transfer(from, to, amount);
    }

}