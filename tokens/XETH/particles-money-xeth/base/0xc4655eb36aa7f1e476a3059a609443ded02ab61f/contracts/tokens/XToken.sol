// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

abstract contract XToken is ERC20Burnable {
    // CONTRACTS
    address public minter;

    /* ========== MODIFIERS ========== */

    modifier onlyMinter() {
        require(minter == msg.sender, "XToken::Only minter can request");
        _;
    }

    /* ========== CONSTRUCTOR ========= */

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

    /* ========== MUTATIVE ========== */

    /// @notice Set minter for XToken (only once)
    /// @param _minter Address of minting Pool
    function setMinter(address _minter) external {
        require(minter == address(0), "XToken::setMinter: NOT_ALLOWED");
        minter = _minter;
    }

    /// @notice Mint new XToken
    /// @param _address Address of receiver
    /// @param _amount Amount of new XToken
    function mint(address _address, uint256 _amount) external onlyMinter {
        _mint(_address, _amount);
    }
}
