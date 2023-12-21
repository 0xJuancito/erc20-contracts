//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ERC20.sol";
import "Initializable.sol";
import "ERC20Upgradeable.sol";
import "OwnableUpgradeable.sol";

interface IBurnMintERC20 is IERC20Upgradeable {
    function mint(address account, uint256 amount) external;
    function burn(uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;
}

contract clDFX is Initializable, ERC20Upgradeable, OwnableUpgradeable, IBurnMintERC20 {
    address private _minter;
    string private _name;
    string private _symbol;
    string private _version;

    modifier onlyMinter() {
        require(msg.sender == _minter, "Not the minter");
        _;
    }

    /// @notice Initializer the ERC20 token.
    /// @param tokenName The name of the token.
    /// @param tokenSymbol The symbol of the token.
    /// @param minter Address designated as the operator with mint and burn privileges.
    /// @param version Version of the token contract
    function initialize(string memory tokenName, string memory tokenSymbol, address minter, string memory version)
        external
        initializer
    {
        __ERC20_init(tokenName, tokenSymbol);
        __Ownable_init();

        _minter = minter;
        _version = version;
    }

    /// @notice Mints new tokens for a given address.
    /// @param account The address to mint the new tokens to.
    /// @param amount The number of tokens to be minted.
    /// @dev this function increases the total supply.
    function mint(address account, uint256 amount) external override onlyMinter {
        _mint(account, amount);
    }

    /// @notice Burns tokens from the message sender.
    /// @param amount The amount of tokens to burn.
    /// @dev this function decreases the total supply.
    function burn(uint256 amount) external override onlyMinter {
        _burn(msg.sender, amount);
    }

    /// @notice Burns tokens from a specific account.
    /// @param account The account from which to burn tokens.
    /// @param amount The amount of tokens to burn.
    /// @dev this function decreases the total supply.
    function burnFrom(address account, uint256 amount) external override onlyMinter {
        _burn(account, amount);
    }

    /// @notice Sets a new minter.
    /// @param newMinter The new minter's address.
    /// @dev Can only be called by the owner.
    function setMinter(address newMinter) external onlyOwner {
        _minter = newMinter;
    }

    /// @notice Retrieves the current minter's address.
    /// @return The address of the current minter.
    function getMinter() external view returns (address) {
        return _minter;
    }
}
