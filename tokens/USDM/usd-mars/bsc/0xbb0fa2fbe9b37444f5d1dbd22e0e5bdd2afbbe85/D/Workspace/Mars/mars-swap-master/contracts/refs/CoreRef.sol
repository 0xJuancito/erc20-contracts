// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import "../interfaces/ICoreRef.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/// @title A Reference to Core
/// @author USDM Protocol
/// @notice Defines some modifiers and utilities around interacting with Core
abstract contract CoreRef is ICoreRef, Pausable {
    ICore private _core;

    /// @notice CoreRef constructor
    /// @param core_ USDM Core to reference
    constructor(address core_) {
        _core = ICore(core_);
    }

    modifier ifMinterSelf() {
        if (_core.isMinter(address(this))) {
            _;
        }
    }

    modifier ifBurnerSelf() {
        if (_core.isBurner(address(this))) {
            _;
        }
    }

    modifier onlyMinter() {
        require(
            _core.isMinter(msg.sender),
            "CoreRef::onlyMinter: Caller is not a minter"
        );
        _;
    }

    modifier onlyBurner() {
        require(
            _core.isBurner(msg.sender),
            "CoreRef::onlyBurner: Caller is not a burner"
        );
        _;
    }

    modifier onlyPCVController() {
        require(
            _core.isPCVController(msg.sender),
            "CoreRef::onlyPCVController: Caller is not a PCV controller"
        );
        _;
    }

    modifier onlyGovernor() {
        require(
            _core.isGovernor(msg.sender),
            "CoreRef::onlyGovernor: Caller is not a governor"
        );
        _;
    }

    modifier onlyGuardianOrGovernor() {
        require(
            _core.isGovernor(msg.sender) || _core.isGuardian(msg.sender),
            "CoreRef::onlyGuardianOrGovernor: Caller is not a guardian or governor"
        );
        _;
    }

    modifier onlyUSDM() {
        require(
            msg.sender == address(usdm()),
            "CoreRef::onlyUSDM: Caller is not USDM"
        );
        _;
    }

    modifier onlyGenesisGroup() {
        require(
            msg.sender == _core.genesisGroup(),
            "CoreRef::onlyGenesisGroup: Caller is not GenesisGroup"
        );
        _;
    }

    modifier postGenesis() {
        require(
            _core.hasGenesisGroupCompleted(),
            "CoreRef::postGenesis: Still in genesis period"
        );
        _;
    }

    modifier nonContract() {
        require(
            !Address.isContract(msg.sender),
            "CoreRef::nonContract: Caller is a contract"
        );
        _;
    }

    /// @notice Set new Core reference address
    /// @param core_ The new core address
    function setCore(address core_) external override onlyGovernor {
        _core = ICore(core_);
        emit CoreUpdate(core_);
    }

    /// @notice Set pausable methods to paused
    function pause() public override onlyGuardianOrGovernor {
        _pause();
    }

    /// @notice Set pausable methods to unpaused
    function unpause() public override onlyGovernor {
        _unpause();
    }

    /// @notice Address of the Core contract referenced
    /// @return ICore implementation address
    function core() public view override returns (ICore) {
        return _core;
    }

    /// @notice Address of the USDM contract referenced by Core
    /// @return IUSDMToken implementation address
    function usdm() public view override returns (IUSDMToken) {
        return _core.usdm();
    }

    /// @notice Address of the XMS contract referenced by Core
    /// @return IUSDMToken implementation address
    function xms() public view override returns (IXMSToken) {
        return _core.xms();
    }

    /// @notice USDM balance of contract
    /// @return USDM amount held
    function usdmBalance() public view override returns (uint256) {
        return usdm().balanceOf(address(this));
    }

    /// @notice XMS balance of contract
    /// @return XMS amount held
    function xmsBalance() public view override returns (uint256) {
        return xms().balanceOf(address(this));
    }

    function _burnUSDMHeld() internal {
        usdm().burn(usdmBalance());
    }

    function _mintUSDM(uint256 amount) internal {
        usdm().mint(address(this), amount);
    }
}
