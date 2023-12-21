//SPDX-License-Identifier: Apache License Version 2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "./interfaces/IERC20Receiver.sol";

/// @title EFI Token
/// @author Enjin
contract EFIToken is ERC20Upgradeable {
    using AddressUpgradeable for address;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @notice address of the invited owner
    address public invitedOwner;

    /// @notice the address of the current owner of the contract
    address public owner;

    event NewOwnerInvited(
        address indexed currentOwner,
        address indexed invitedOwner
    );

    event InvitationRevoked(
        address indexed currentOwner,
        address indexed invitedOwner
    );

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /// @param initialSupply the initial supply of tokens
    /// @param _owner Address owning the total supply
    function initialize(uint256 initialSupply, address _owner) public initializer {
        __ERC20_init("Efinity Token", "EFI");
        _mint(_owner, initialSupply);
        owner = _owner;
        emit OwnershipTransferred(address(0), _owner);
    }

    modifier onlyOwner {
        require(msg.sender == owner, "Efinity Token: caller is not the owner");

        _;
    }

    /// @notice As Owner, invite another account to take ownership of the contract
    /// @param _invitedOwner address of the invited owner
    function inviteNewOwner(address _invitedOwner) external virtual onlyOwner {
        invitedOwner = _invitedOwner;

        emit NewOwnerInvited(owner, _invitedOwner);
    }

    /// @notice As Owner, revoke the invitation sent to an account
    /// @param _invitedOwner address of the invited owner
    function revokeInvitation(address _invitedOwner)
        external
        virtual
        onlyOwner
    {
        require(
            invitedOwner == _invitedOwner,
            "Efinity Token: not invited owner"
        );

        delete invitedOwner;

        emit InvitationRevoked(owner, _invitedOwner);
    }

    /// @notice As the Invited Owner, accept the invitation to take ownership of the contract
    function acceptOwnership() external virtual {
        require(
            msg.sender == invitedOwner,
            "Efinity Token: caller is not invited owner"
        );

        delete invitedOwner;

        emit OwnershipTransferred(owner, msg.sender);

        owner = msg.sender;
    }

    /// @notice As Owner, withdraw tokens sent to this account
    /// @param _token address of the token contract
    /// @param _to recipient address
    /// @param _amount number of tokens to transfer
    /// @return true if successful
    function withdrawTokens(
        address _token,
        address _to,
        uint256 _amount
    ) external virtual onlyOwner returns (bool) {
        IERC20Upgradeable(_token).safeTransfer(_to, _amount);

        return true;
    }

    /// @notice safely transfer tokens to externally-owned accounts or contracts
    /// @param recipient recipient address
    /// @param amount number of tokens to transfer
    /// @return true if successful
    function safeTransfer(address recipient, uint256 amount)
        public
        virtual
        returns (bool)
    {
        super.transfer(recipient, amount);

        address operator = msg.sender;

        _doSafeTransferAcceptanceCheck(
            operator,
            operator,
            recipient,
            amount,
            ""
        );

        return true;
    }

    /// @notice safely transfer tokens to externally-owned accounts or contracts
    /// @dev for transfers that include arbitrary data for the recipient
    /// @param recipient recipient address
    /// @param amount number of tokens to transfer
    /// @param data arbitrary data for the recipient
    /// @return true if successful
    function safeTransfer(
        address recipient,
        uint256 amount,
        bytes memory data
    ) public virtual returns (bool) {
        super.transfer(recipient, amount);

        address operator = msg.sender;

        _doSafeTransferAcceptanceCheck(
            operator,
            operator,
            recipient,
            amount,
            data
        );

        return true;
    }

    /// @notice safely transfer tokens from one account to another externally-owned account or contract
    /// @param recipient recipient address
    /// @param amount number of tokens to transfer
    /// @return true if successful
    function safeTransferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual returns (bool) {
        super.transferFrom(sender, recipient, amount);

        address operator = msg.sender;

        _doSafeTransferAcceptanceCheck(operator, sender, recipient, amount, "");

        return true;
    }

    /// @notice safely transfer tokens from one account to another externally-owned account or contract
    /// @dev for transfers that include arbitrary data for the recipient
    /// @param recipient recipient address
    /// @param amount number of tokens to transfer
    /// @param data arbitrary data for the recipient
    /// @return true if successful
    function safeTransferFrom(
        address sender,
        address recipient,
        uint256 amount,
        bytes memory data
    ) public virtual returns (bool) {
        super.transferFrom(sender, recipient, amount);

        address operator = msg.sender;

        _doSafeTransferAcceptanceCheck(
            operator,
            sender,
            recipient,
            amount,
            data
        );

        return true;
    }

    /// @notice check that recipient contract account implements onERC20Received
    /// @param operator the msg.sender
    /// @param from transfer from account
    /// @param to transfer to account
    /// @param amount number of tokens to transfer
    /// @param data arbitrary data for the recipient
    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try
                IERC20Receiver(to).onERC20Received(operator, from, amount, data)
            returns (bytes4 response) {
                if (response != IERC20Receiver(to).onERC20Received.selector) {
                    revert("ERC20: ERC20Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC20: transfer to non ERC20Receiver implementer");
            }
        }
    }
}
