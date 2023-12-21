// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {
    UUPSUpgradeable, StorageSlotUpgradeable
} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Ownable2StepUpgradeable} from "openzeppelin-contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {PausableUpgradeable} from "openzeppelin-contracts-upgradeable/security/PausableUpgradeable.sol";
import {ERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20CappedUpgradeable} from
    "openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";
import {ERC20BurnableUpgradeable} from
    "openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {ERC20SnapshotUpgradeable} from
    "openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC20SnapshotUpgradeable.sol";

contract ZeemcoinToken is
    Initializable,
    ERC20Upgradeable,
    ERC20CappedUpgradeable,
    ERC20BurnableUpgradeable,
    ERC20SnapshotUpgradeable,
    Ownable2StepUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    uint256 public burned;

    constructor() {
        _disableInitializers();
    }

    function initialize(address owner_) public initializer {
        uint256 cap_ = 100e6 ether;
        __ERC20_init("Zeemcoin token", "ZEEM");
        __ERC20Capped_init(cap_);
        __ERC20Burnable_init();
        __ERC20Snapshot_init();
        __Ownable_init();
        _transferOwnership(owner_);
        __Pausable_init();
        __UUPSUpgradeable_init();

        _mint(msg.sender, cap_);
    }

    function reinitialize() public reinitializer(2) {
        __ERC20_init("Zeemcoin", "ZEEM");
    }

    function snapshot() public onlyOwner {
        _snapshot();
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function burn(uint256 amount) public override {
        burned += amount;
        super.burn(amount);
    }

    function burnFrom(address account, uint256 amount) public override {
        burned += amount;
        super.burnFrom(account, amount);
    }

    function _mint(address account, uint256 amount)
        internal
        virtual
        override(ERC20Upgradeable, ERC20CappedUpgradeable)
    {
        ERC20CappedUpgradeable._mint(account, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20Upgradeable, ERC20SnapshotUpgradeable)
        whenNotPaused
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _authorizeUpgrade(address) internal view override onlyOwner {
        revert("ZEEM: not upgradeable");
    }
}
