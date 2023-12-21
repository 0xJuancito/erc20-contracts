// SPDX-License-Identifier: MIT
// https://github.com/ethereum-optimism/optimism/blob/de51656edb881d744681d9e1dbb1bfdefb4a8c83/packages/contracts-bedrock/src/universal/OptimismMintableERC20.sol
pragma solidity ^0.8.20;

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {ERC20Permit, Nonces} from "openzeppelin-contracts/token/ERC20/extensions/ERC20Permit.sol";
import {IERC165} from "openzeppelin-contracts/utils/introspection/IERC165.sol";
import {IOptimismMintableERC20} from "./interfaces/IOptimismMintableERC20.sol";

/// @title SeamL1
/// @author Seamless Protocol
/// @notice OptimismMintableERC20 is a standard extension of the base ERC20 token contract designed
///         to allow the StandardBridge contracts to mint and burn tokens. This makes it possible to
///         use an OptimismMintablERC20 as the L2 representation of an L1 token, or vice-versa.
contract SeamL1 is IOptimismMintableERC20, ERC20, ERC20Permit {
    /// @notice Address of the StandardBridge on this network.
    address public immutable bridge;

    /// @notice Address of the corresponding version of this token on the remote chain.
    address public immutable remoteToken;

    /// @notice Emitted whenever tokens are minted for an account.
    /// @param account Address of the account tokens are being minted for.
    /// @param amount  Amount of tokens minted.
    event Mint(address indexed account, uint256 amount);

    /// @notice Emitted whenever tokens are burned from an account.
    /// @param account Address of the account tokens are being burned from.
    /// @param amount  Amount of tokens burned.
    event Burn(address indexed account, uint256 amount);

    /// @notice OptimismMintableERC20: only bridge can mint and burn
    error NotBridge();

    /// @notice A modifier that only allows the bridge to call
    modifier onlyBridge() {
        if (msg.sender != bridge) revert NotBridge();
        _;
    }

    constructor(address _bridge, address _remoteToken, string memory _name, string memory _symbol)
        ERC20(_name, _symbol)
        ERC20Permit(_name)
    {
        bridge = _bridge;
        remoteToken = _remoteToken;
    }

    /// @notice Allows the StandardBridge on this network to mint tokens.
    /// @param _to     Address to mint tokens to.
    /// @param _amount Amount of tokens to mint.
    function mint(address _to, uint256 _amount) external virtual override onlyBridge {
        _mint(_to, _amount);
        emit Mint(_to, _amount);
    }

    /// @notice Allows the StandardBridge on this network to burn tokens.
    /// @param _from   Address to burn tokens from.
    /// @param _amount Amount of tokens to burn.
    function burn(address _from, uint256 _amount) external virtual override onlyBridge {
        _burn(_from, _amount);
        emit Burn(_from, _amount);
    }

    /// @notice ERC165 interface check function.
    /// @param _interfaceId Interface ID to check.
    /// @return Whether or not the interface is supported by this contract.
    function supportsInterface(bytes4 _interfaceId) external pure virtual returns (bool) {
        bytes4 iface1 = type(IERC165).interfaceId;
        // Interface corresponding to the updated OptimismMintableERC20 (this contract).
        bytes4 iface3 = type(IOptimismMintableERC20).interfaceId;
        return _interfaceId == iface1 || _interfaceId == iface3;
    }
}
