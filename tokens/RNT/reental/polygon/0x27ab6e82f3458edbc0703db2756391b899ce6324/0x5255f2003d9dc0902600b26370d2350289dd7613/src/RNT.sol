// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Ownable2StepUpgradeable} from "openzeppelin-contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {PausableUpgradeable} from "openzeppelin-contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20CappedUpgradeable} from
    "openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";
import {ERC20BurnableUpgradeable} from
    "openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {IRNTPairOracle} from "src/interfaces/IRNTPairOracle.sol";

contract RNT is
    Initializable,
    ERC20Upgradeable,
    ERC20CappedUpgradeable,
    ERC20BurnableUpgradeable,
    Ownable2StepUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    uint256 public burned;
    IRNTPairOracle public pairOracle;

    constructor() {
        _disableInitializers();
    }

    function initialize(address owner_, address pairOracle_) public initializer {
        uint256 cap_ = 200e6 ether;
        __ERC20_init("Reental Utility Token", "RNT");
        __ERC20Capped_init(cap_);
        __ERC20Burnable_init();
        __Ownable_init(owner_);
        __Ownable2Step_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        _mint(msg.sender, cap_);
        pairOracle = IRNTPairOracle(pairOracle_);
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

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function _update(address from, address to, uint256 amount)
        internal
        override(ERC20CappedUpgradeable, ERC20Upgradeable)
        whenNotPaused
    {
        if (!_isInitializing()) require(pairOracle.checkTransfer(from, to, amount), "RNT:only swap manager");
        super._update(from, to, amount);
    }

    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
        (newImplementation);
    }
}
