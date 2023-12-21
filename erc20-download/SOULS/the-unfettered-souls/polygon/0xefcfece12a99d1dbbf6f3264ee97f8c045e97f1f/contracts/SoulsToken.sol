// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IManagers.sol";
import "./interfaces/IBotPrevention.sol";

contract SoulsToken is ERC20, Ownable {
    //Storage Variables
    IBotPrevention botPrevention;
    IManagers managers;

    uint256 public constant maxSupply = 3000000000 ether;

    bool public botPreventionEnabled = true;

    //Custom Errors
    error BotPreventionError();
    error AlreadyDisabled();
    error AlreadyEnabled();
    error NotAuthorized();

    //Events
    event DisableBotPrevention(address manager, bool isApproved);
    event EnableBotPrevention(address manager, bool isApproved);

    constructor(
        string memory _name,
        string memory _symbol,
        address _managers,
        address _botPrevention
    ) ERC20(_name, _symbol) {
        botPrevention = IBotPrevention(_botPrevention);
        managers = IManagers(_managers);
        _mint(msg.sender, maxSupply);
    }

    modifier onlyManager() {
        if (!managers.isManager(msg.sender)) {
            revert NotAuthorized();
        }
        _;
    }

    function disableBotPrevention() external onlyManager {
        if (!botPreventionEnabled) {
            revert AlreadyDisabled();
        }
        string memory _title = "Set Bot Prevention Status";
        bytes memory _encodedValues = abi.encode(0);
        managers.approveTopic(_title, _encodedValues);
        bool _isApproved = managers.isApproved(_title, _encodedValues);
        if (_isApproved) {
            botPreventionEnabled = false;
            managers.deleteTopic(_title);
        }
        emit DisableBotPrevention(msg.sender, _isApproved);
    }

    function enableBotPrevention() external onlyManager {
        if (botPreventionEnabled) {
            revert AlreadyEnabled();
        }
        string memory _title = "Set Bot Prevention Status";
        bytes memory _encodedValues = abi.encode(0);
        managers.approveTopic(_title, _encodedValues);
        bool _isApproved = managers.isApproved(_title, _encodedValues);
        if (_isApproved) {
            botPreventionEnabled = true;
            managers.deleteTopic(_title);
            botPrevention.resetBotPreventionData();
        }
        emit EnableBotPrevention(msg.sender, _isApproved);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal view override {
        if (botPreventionEnabled && from != address(0)) {
            if (!managers.isManager(tx.origin) || !managers.isTrustedSource(msg.sender)) {
                if (!botPrevention.beforeTokenTransfer(from, to, amount)) {
                    revert BotPreventionError();
                }
            }
        }
    }

    function _afterTokenTransfer(address from, address to, uint256 amount) internal override {
        if (botPreventionEnabled && from != address(0)) {
            if (!managers.isManager(tx.origin) || !managers.isTrustedSource(msg.sender)) {
                if (!botPrevention.afterTokenTransfer(from, to, amount)) {
                    revert BotPreventionError();
                }
            }
        }
    }
}
