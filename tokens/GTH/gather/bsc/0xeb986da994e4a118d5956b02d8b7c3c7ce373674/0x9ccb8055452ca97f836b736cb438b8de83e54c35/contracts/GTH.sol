//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

import "hardhat/console.sol";

contract GTH is
    Initializable,
    ContextUpgradeable,
    OwnableUpgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable
{
    uint256 public constant maxMintLimit = 400000000 ether;

    mapping(address => bool) public blacklisted;

    function GTH_init() public initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
        __ERC20_init_unchained("Gather", "GTH");
        __ERC20Burnable_init_unchained();
        __Pausable_init_unchained();
        __ERC20Pausable_init_unchained();
    }

    event Mint(address indexed to, uint256 amount);

    function addToBlackList(address account) public onlyOwner {
        require(account != owner(), "GTH: account can not be owner");
        require(!blacklisted[account], "GTH: account already blacklisted");
        blacklisted[account] = true;
    }

    function removeFromBlackList(address account) public onlyOwner {
        require(blacklisted[account], "GTH: account is not blacklisted");
        delete blacklisted[account];
    }

    function isBlacklisted(address account) external view returns (bool) {
        return blacklisted[account];
    }

    function mint(address to, uint256 amount) 
        public 
        virtual 
        onlyOwner
    {
        require(
            totalSupply() + amount <= maxMintLimit,
            "GTH: total supply reached max mint limit"
        );
        _mint(to, amount);
        emit Mint(to, amount);
    }

    function pause() public virtual onlyOwner {
        _pause();
    }

    function unpause() public virtual onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        require(!blacklisted[from], "GTH: from account is blacklisted");
        require(!blacklisted[to], "GTH: to account is blacklisted");
        require(!blacklisted[_msgSender()], "GTH: account is blacklisted");

        super._beforeTokenTransfer(from, to, amount);
    }

    function transferOwnership(address newOwner)
        public
        virtual
        override
    {
        require(!blacklisted[newOwner], "GTH: new owner account is blacklisted");
        super.transferOwnership(newOwner);
    }
}
