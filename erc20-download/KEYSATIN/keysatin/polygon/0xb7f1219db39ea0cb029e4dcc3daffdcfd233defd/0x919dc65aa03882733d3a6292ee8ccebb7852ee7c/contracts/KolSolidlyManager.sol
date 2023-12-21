// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "./AuthUpgradeable.sol";
contract KolSolidlyManager is AuthUpgradeable, PausableUpgradeable {
    function _authorizeUpgrade(address) internal override onlyOwner {}
    /**
   * {keeper} - Address to manage a few lower risk features of the strat..
   */
    address public keeper;
    address public voter;

    event NewKeeper(address oldKeeper, address newKeeper);
    event NewVoter(address newVoter);

    function __KolSolidlyManager_init(address _keeper, address _voter) internal initializer {
        __KolSolidlyManager_init_unchained(_keeper, _voter);
    }

    function __KolSolidlyManager_init_unchained(address _keeper, address _voter) internal initializer {
        keeper = _keeper;
        voter = _voter;
    }

    // Checks that caller is either owner or keeper.
    modifier onlyManager() {
        require(msg.sender == owner || msg.sender == keeper, "!manager");
        _;
    }

    // Checks that caller is either owner or keeper.
    modifier onlyVoter() {
        require(msg.sender == voter, "!voter");
        _;
    }

    /**
     * @dev Updates address of the strat keeper.
   * @param _keeper new keeper address.
   */
    function setKeeper(address _keeper) external onlyManager {
        emit NewKeeper(keeper, _keeper);
        keeper = _keeper;
    }

    function setVoter(address _voter) external onlyManager {
        emit NewVoter(_voter);
        voter = _voter;
    }
}