// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./utils/ERC20.sol";
import "./utils/Owned.sol";
import "./interfaces/ISupplySchedule.sol";
import "./interfaces/IDexToro.sol";

contract DexToro is ERC20, Owned, IDexToro {
    /// @notice defines inflationary supply schedule,
    /// according to which the DTORO inflationary supply is released
    ISupplySchedule public supplySchedule;

    modifier onlySupplySchedule() {
        require(
            msg.sender == address(supplySchedule),
            "DexToro: Only SupplySchedule can perform this action"
        );
        _;
    }

    constructor(
        string memory name,
        string memory symbol,
        uint256 _initialSupply,
        address _owner,
        address _initialHolder
    ) ERC20(name, symbol) Owned(_owner) {
        _mint(_initialHolder, _initialSupply);
    }

    // Mints inflationary supply
    function mint(
        address account,
        uint256 amount
    ) external override onlySupplySchedule {
        _mint(account, amount);
    }

    function burn(uint256 amount) external override {
        _burn(msg.sender, amount);
    }

    function setSupplySchedule(
        address _supplySchedule
    ) external override onlyOwner {
        require(_supplySchedule != address(0), "DexToro: Invalid Address");
        supplySchedule = ISupplySchedule(_supplySchedule);
    }
}
