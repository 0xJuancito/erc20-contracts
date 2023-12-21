// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "./ApproveWithAuthorization.sol";

contract GiddyToken is OwnableUpgradeable, ApproveWithAuthorization {
    
    function initialize(string calldata _name, string calldata _symbol, string calldata version) public initializer
    {
        __ERC20_init(_name, _symbol);
        __Ownable_init();
        _mint(msg.sender, 1000000000 * (10**uint256(decimals())));

        DOMAIN_SEPARATOR = EIP712.makeDomainSeparator(_name, version);
    }

    function symbol() public view virtual override returns (string memory) {
        return "GIDDY";
    }
}
