// SPDX-License-Identifier: UNLICENSED

// Copyright (c) 2023 Jones DAO - All rights reserved
// Jones DAO: https://www.jonesdao.io/

pragma solidity ^0.8.10;

import {ERC4626} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {JonesUsdVault} from "../../vaults/JonesUsdVault.sol";
import {JonesBorrowableVault} from "../../vaults/JonesBorrowableVault.sol";
import {JonesOperableVault} from "../../vaults/JonesOperableVault.sol";
import {JonesGovernableVault} from "../../vaults/JonesGovernableVault.sol";
import {IAggregatorV3} from "../../interfaces/IAggregatorV3.sol";
import {IStakedGlp} from "../../interfaces/IStakedGlp.sol";
import {IJonesGlpLeverageStrategy} from "../../interfaces/IJonesGlpLeverageStrategy.sol";

abstract contract JonesBaseGlpVault is JonesOperableVault, JonesUsdVault, JonesBorrowableVault {
    IJonesGlpLeverageStrategy public strategy;
    address internal receiver;

    constructor(IAggregatorV3 _oracle, IERC20Metadata _asset, string memory _name, string memory _symbol)
        JonesGovernableVault(msg.sender)
        JonesUsdVault(_oracle)
        ERC4626(_asset)
        ERC20(_name, _symbol)
    {}

    // ============================= Operable functions ================================ //

    /**
     * @dev See {openzeppelin-IERC4626-deposit}.
     */
    function deposit(uint256 _assets, address _receiver)
        public
        virtual
        override(JonesOperableVault, ERC4626)
        whenNotPaused
        returns (uint256)
    {
        return super.deposit(_assets, _receiver);
    }

    /**
     * @dev See {openzeppelin-IERC4626-mint}.
     */
    function mint(uint256 _shares, address _receiver)
        public
        override(JonesOperableVault, ERC4626)
        whenNotPaused
        returns (uint256)
    {
        return super.mint(_shares, _receiver);
    }

    /**
     * @dev See {openzeppelin-IERC4626-withdraw}.
     */
    function withdraw(uint256 _assets, address _receiver, address _owner)
        public
        virtual
        override(JonesOperableVault, ERC4626)
        returns (uint256)
    {
        return super.withdraw(_assets, _receiver, _owner);
    }

    /**
     * @dev See {openzeppelin-IERC4626-redeem}.
     */
    function redeem(uint256 _shares, address _receiver, address _owner)
        public
        virtual
        override(JonesOperableVault, ERC4626)
        returns (uint256)
    {
        return super.redeem(_shares, _receiver, _owner);
    }

    /**
     * @notice Set new strategy address
     * @param _strategy Strategy Contract
     */
    function setStrategyAddress(IJonesGlpLeverageStrategy _strategy) external onlyGovernor {
        strategy = _strategy;
    }

    function setExcessReceiver(address _receiver) external onlyGovernor {
        receiver = _receiver;
    }
}
