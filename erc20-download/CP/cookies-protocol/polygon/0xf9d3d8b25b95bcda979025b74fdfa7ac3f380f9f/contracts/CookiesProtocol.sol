//SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

/**
 * @title CookiesProtocol
 * @author gotbit
 */

import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

interface IAntisnipe {
    function assureCanTransfer(
        address sender,
        address from,
        address to,
        uint256 amount
    ) external;
}

contract CookiesProtocol is ERC20Burnable, Ownable {
    /// @dev collection of unlock times for user
    mapping(address => uint256) private _unlockTimes;

    /// @dev address of antisnipe contract
    IAntisnipe public antisnipe;
    /// @dev status of antisnipe
    bool public antisnipeDisable;

    constructor() ERC20('Cookies Protocol', 'CP') {
        // mint initial supply to deployer
        _mint(msg.sender, 100_000_000_000_000 ether);
    }

    /// @inheritdoc ERC20
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        /// prevent transfer tokens for locked users
        require(_unlockTimes[from] <= block.timestamp, 'Sender wallet is locked');

        /// antisnipe call
        if (!antisnipeDisable && address(antisnipe) != address(0))
            antisnipe.assureCanTransfer(msg.sender, from, to, amount);
    }

    /// @dev sets unlock times for users (only owner) (100 users per call)
    /// @param users addresses of users
    /// @param timestamps unlock timestamps corresponding to users
    function setUnlockTimes(address[] calldata users, uint256[] calldata timestamps)
        external
        onlyOwner
    {
        require(users.length <= 100, 'Too much elements in array');
        require(timestamps.length == users.length, 'Different sizes of arrays');
        uint256 length = users.length;
        for (uint256 i; i < length; ++i) _unlockTimes[users[i]] = timestamps[i];
    }

    /// @dev disables antisnipe **one-way!!!** (only owner)
    function setAntisnipeDisable() external onlyOwner {
        require(!antisnipeDisable);
        antisnipeDisable = true;
    }

    /// @dev sets new antisnipe address (only owner)
    /// @param addr address of antisnipe
    function setAntisnipeAddress(address addr) external onlyOwner {
        antisnipe = IAntisnipe(addr);
    }
}
