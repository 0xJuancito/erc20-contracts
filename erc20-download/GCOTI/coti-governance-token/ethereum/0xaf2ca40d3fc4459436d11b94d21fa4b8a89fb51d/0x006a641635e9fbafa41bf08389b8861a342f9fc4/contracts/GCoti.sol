// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./MaxSupplyToken.sol";
import "./BlacklistContract.sol";


contract GCoti is Initializable, ERC20BurnableUpgradeable, OwnableUpgradeable, ERC20PermitUpgradeable, UUPSUpgradeable, MaxSupplyERC20Upgradeable, Blacklistable {
    /// @custom:oz-upgrades-unsafe-allow constructor

    constructor() {
        _disableInitializers();
    }

    function initialize() initializer public {
        __initializeErc20("gCOTI Token", "gCOTI", 2000000000000000000000000000);
        __ERC20Burnable_init();
        __Ownable_init();
        __ERC20Permit_init("gCoti Token");
        __UUPSUpgradeable_init();
    }

    function mint(address to, uint256 amount) public onlyOwner {
        require(!isBlacklisted(to), "Sender is blacklisted");
        __mint(to, amount);
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        require(!isBlacklisted(msg.sender), "Sender is blacklisted");
        require(!isBlacklisted(to), "Receiver is blacklisted");
        super.transfer(to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        require(!isBlacklisted(from), "Sender is blacklisted");
        require(!isBlacklisted(to), "receiver is blacklisted");
        super.transferFrom(from, to, amount);
        return true;
    }

    function blacklist(address _account) public virtual onlyOwner {
        _blacklist(_account);
    }

    function unBlacklist(address _account) public virtual onlyOwner {
        _unBlacklist(_account);
    }

    function _authorizeUpgrade(address newImplementation)
    internal
    onlyOwner
    override
    {}
}
