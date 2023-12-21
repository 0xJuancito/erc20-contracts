// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

import "./library/Capped.sol";
import "./OFT/OFTV2Upgradeable.sol";

contract UnitusOFT is ERC20PermitUpgradeable, Capped, OFTV2Upgradeable {
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _cap,
        uint8 _sharedDecimals,
        address _lzEndpoint
    ) OFTV2Upgradeable(_sharedDecimals, _lzEndpoint) {
        initialize(_name, _symbol, _cap);
    }

    function initialize(string memory _name, string memory _symbol, uint256 _cap) public initializer {
        __OFTV2Upgradeable_init(_name, _symbol);
        __ERC20Permit_init(_name);
        _setCapInternal(_cap);
    }

    function _setMaxSupply(uint256 _cap) public onlyOwner {
        _setCapInternal(_cap);
    }

    function _mint(address account, uint256 amount) internal override {
        require(totalSupply() + amount <= cap_, "_mint: cap exceeded");
        super._mint(account, amount);
    }

    function _msgSender() internal view virtual override(OFTV2Upgradeable, ContextUpgradeable) returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual override(OFTV2Upgradeable, ContextUpgradeable) returns (bytes calldata) {
        return msg.data;
    }
}
