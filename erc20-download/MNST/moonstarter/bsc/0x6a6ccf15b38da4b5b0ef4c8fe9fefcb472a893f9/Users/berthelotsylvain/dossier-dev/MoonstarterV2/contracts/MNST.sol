// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MNST is ERC20, Ownable {
    constructor() ERC20("MoonStarter.net", "MNST") {
        _mint(msg.sender, 200000000 * 1E18);
        locked = true;
        _auth[msg.sender] = true;
    }

    function getOwner() external view returns (address) {
        return owner();
    }

    // Temp locked at deployment
    // prevent any listing by anyone else team
    bool locked;
    mapping(address => bool) _auth;

    function addAuth(address _a) external onlyOwner {
        _auth[_a] = true;
    }

    function removeAuth(address _a) external onlyOwner {
        _auth[_a] = false;
    }

    function unlockTokens() external onlyOwner {
        locked = false;
    }

    // override transfer and transferFrom
    // prevent any listing by anyone else team

    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        require(!locked || _auth[msg.sender], "Token is not unlock yet");
        return super.transfer(recipient, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        require(!locked || _auth[sender], "Token is not unlock yet");
        return super.transferFrom(sender, recipient, amount);
    }
}
