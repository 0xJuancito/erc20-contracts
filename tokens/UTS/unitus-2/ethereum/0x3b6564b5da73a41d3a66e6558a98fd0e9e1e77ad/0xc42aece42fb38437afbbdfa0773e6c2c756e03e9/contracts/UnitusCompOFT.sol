// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesCompUpgradeable.sol";

import "./library/Capped.sol";
import "./OFT/OFTV2Upgradeable.sol";

contract UnitusCompOFT is ERC20VotesCompUpgradeable, Capped, OFTV2Upgradeable {
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _cap,
        address _treasury,
        uint8 _sharedDecimals,
        address _lzEndpoint
    ) OFTV2Upgradeable(_sharedDecimals, _lzEndpoint) {
        initialize(_name, _symbol, _cap, _treasury);
    }

    function initialize(
        string memory _name,
        string memory _symbol,
        uint256 _cap,
        address _treasury
    ) public initializer {
        __OFTV2Upgradeable_init(_name, _symbol);
        __ERC20Permit_init(_name);
        _setCapInternal(_cap);
        _mint(_treasury, _cap);
    }

    function _setMaxSupply(uint256 _cap) public onlyOwner {
        _setCapInternal(_cap);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        ERC20VotesUpgradeable._afterTokenTransfer(from, to, amount);
    }

    function _burn(address account, uint256 amount) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        ERC20VotesUpgradeable._burn(account, amount);
    }

    function _mint(address account, uint256 amount) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        require(totalSupply() + amount <= cap_, "_mint: cap exceeded");
        ERC20VotesUpgradeable._mint(account, amount);
    }

    function _msgSender() internal view virtual override(OFTV2Upgradeable, ContextUpgradeable) returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual override(OFTV2Upgradeable, ContextUpgradeable) returns (bytes calldata) {
        return msg.data;
    }
}
