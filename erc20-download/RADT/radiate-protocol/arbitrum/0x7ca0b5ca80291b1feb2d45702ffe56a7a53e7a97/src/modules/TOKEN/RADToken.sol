// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "src/Kernel.sol";

/// @title RADToken
/// @notice RADToken is a contract for the RAD token.
contract RADToken is ERC20, Module {
    //============================================================================================//
    //                                        MODULE SETUP                                        //
    //============================================================================================//

    /// @notice Initializes the contract.
    constructor(
        Kernel kernel_ // Why isn't this a Kernel for deploy?
    ) Module(kernel_) ERC20("Radiate Token", "RADT") {}

    /// @inheritdoc Module
    function KEYCODE() public pure override returns (Keycode) {
        return toKeycode("TOKEN");
    }

    uint256 public maxSupply;

    /// @inheritdoc Module
    function VERSION()
        external
        pure
        override
        returns (uint8 major, uint8 minor)
    {
        major = 1;
        minor = 0;
    }

    //============================================================================================//
    //                                       CORE FUNCTIONS                                       //
    //============================================================================================//

    function mint(address _to, uint256 _amount) external permissioned {
        require(
            totalSupply() + _amount <= maxSupply,
            "RADToken: max supply exceeded"
        );
        _mint(_to, _amount);
    }

    function setMaxSupply(uint256 _amount) external permissioned {
        maxSupply = _amount;
    }
}
