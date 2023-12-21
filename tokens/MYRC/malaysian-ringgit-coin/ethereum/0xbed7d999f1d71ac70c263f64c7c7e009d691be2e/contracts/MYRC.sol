//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit, IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {IMYRC} from "./IMYRC.sol";

contract MYRC is IMYRC, ERC20, ERC20Permit, AccessControl {
    bytes32 public constant POLICE_ROLE = keccak256("POLICE_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    mapping(address => bool) public restrictedAddresses;

    constructor(
        address admin,
        address minter,
        address police
    ) ERC20("MYRC", "MYRC") ERC20Permit("MYRC") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(POLICE_ROLE, police);
    }

    /// @notice Mint new tokens
    /// @param to Address to mint tokens to
    /// @param amount Amount of tokens to mint
    /// @dev This function can only be called by an operator
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /// @notice Restrict or unrestrict an address from transfering tokens
    /// @param addr Address to restrict or unrestrict
    /// @param flag Restrict or unrestrict
    /// @dev This function can only be called by an operator
    function restrictAddress(
        address addr,
        bool flag
    ) external onlyRole(POLICE_ROLE) {
        if (restrictedAddresses[addr] == flag)
            revert SameRestrictionFlag(addr, flag);
        restrictedAddresses[addr] = flag;
        emit Restricted(addr, flag);
    }

    /// @notice Incase of ERC20 token balance in the contract address
    /// @param tokenAddress Address of the ERC20 token to rescue
    /// @param to Address to send the ERC20 token balance to
    function rescueToken(
        address tokenAddress,
        address to
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (to == address(0)) revert NoZeroAddress();
        ERC20 token = ERC20(tokenAddress);
        bool success = token.transfer(to, token.balanceOf(address(this)));
        if (!success) revert ERC20RescueFailed(tokenAddress);
    }

    /// @notice Incase of ether balance in the contract address
    /// @param to Address to send the ether balance to
    function rescueEth(
        address payable to
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (to == address(0)) revert NoZeroAddress();
        (bool success, ) = to.call{value: address(this).balance}("");
        if (!success) revert ETHRescueFailed();
    }

    /// @notice Overriding the transfer function to check for restricted addresses
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256
    ) internal virtual override {
        if (restrictedAddresses[from] == true)
            revert FromRestrictedAddress(from);
        if (restrictedAddresses[to] == true) revert ToRestrictedAddress(to);
    }

    /// @notice Overriding the supportsInterface function to support ERC20
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(AccessControl) returns (bool) {
        return
            interfaceId == type(IERC20).interfaceId ||
            interfaceId == type(IERC20Permit).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
