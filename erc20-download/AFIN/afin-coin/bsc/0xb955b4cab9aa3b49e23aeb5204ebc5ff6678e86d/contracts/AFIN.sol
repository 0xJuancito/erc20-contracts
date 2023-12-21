// "SPDX-License-Identifier: MIT"

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract AFIN is ERC20Burnable, AccessControlEnumerable, ERC20Permit, ERC20Votes
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    

    constructor(address _admin) ERC20("Asian Fintech", "Afin") ERC20Permit("Afin")
    {
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(MINTER_ROLE, _admin);
        _setupRole(BURNER_ROLE, _admin);
    }

    modifier onlyMinter 
    {
        require(hasRole(MINTER_ROLE, msg.sender), "Caller is not a minter");
        _;
    }

    modifier onlyBurner 
    {
        require(hasRole(BURNER_ROLE, msg.sender), "Caller is not a burner");
        _;
    }

    modifier onlyAdmin 
    {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not a admin");
        _;
    }

    function mint(address receiver, uint256 amount) 
        external onlyMinter 
    {
        _mint(receiver, amount);
    }

    function grantMinter(address minter) 
        external onlyAdmin 
    {
        grantRole(MINTER_ROLE, minter);
    }

    function revokeMinter(address minter) 
        external onlyAdmin 
    {
        revokeRole(MINTER_ROLE, minter);
    }

    function burn(address account, uint256 amount) 
        external onlyBurner 
    {
        _burn(account, amount);
    }

    function grantBurner(address burner) 
        external onlyAdmin 
    {
        grantRole(BURNER_ROLE, burner);
    }

    function revokeBurner(address burner) 
        external onlyAdmin 
    {
        revokeRole(BURNER_ROLE, burner);
    }

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }
}
