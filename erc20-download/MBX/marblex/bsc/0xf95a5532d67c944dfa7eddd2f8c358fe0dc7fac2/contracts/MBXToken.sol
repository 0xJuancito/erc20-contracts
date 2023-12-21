// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
// solhint-disable-next-line max-line-length
import {ERC20PresetMinterPauser, ERC20, AccessControl, IAccessControl} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ERC2771} from "./ERC2771.sol";

import {IMBXToken} from "./interfaces/IMBXToken.sol";

/**
 * @dev The MBXToken contract implements ERC-2612 and ERC-2771 to support gas fees.
 * The MBXToken contract has an eip712Domain function for using ERC-2612.
 * The TokenForwarder contract has an eip712Domain function for using ERC-2771.
 */
contract MBXToken is Ownable2Step, ERC20PresetMinterPauser, ERC20Permit, ERC2771, IMBXToken {
    using Address for address;

    string public constant VERSION = "v1.0.0";

    mapping(address => bool) public frozenAccount;

    modifier notFrozen(address holder) {
        _checkFrozen(holder);
        _;
    }

    /**
     * @dev The ERC20Permit constructor sets the `version` to `"1"`.
     * The DEFAULT_ADMIN_ROLE is the same as the owner.
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 amount
    ) ERC20PresetMinterPauser(name, symbol) ERC20Permit(name) {
        if (amount > 0) {
            mint(_msgSender(), amount);
        }
    }

    function setFreezeMany(address[] calldata holders, bool[] calldata status) external onlyOwner returns (bool) {
        require(holders.length == status.length, "SFM01");
        for (uint256 i = 0; i < holders.length; i++) {
            require(setFreeze(holders[i], status[i]), "SFM02");
        }
        return true;
    }

    function transferMany(
        address[] calldata recipientList,
        uint256[] calldata amountList,
        uint256 burnAmount
    ) external returns (bool) {
        require(recipientList.length == amountList.length, "TM01");
        for (uint256 i = 0; i < recipientList.length; i++) {
            require(transfer(recipientList[i], amountList[i]), "TM02");
        }
        if (burnAmount > 0) {
            burn(burnAmount);
        }
        return true;
    }

    /*
     * @dev The new owner becomes the owner only after executing acceptOwnership.
     * The owner basically has all roles.
     * The owner role is then revoked and set to beforeOwner.
     */
    function acceptOwnership() public override {
        address beforeOwner = getRoleMember(DEFAULT_ADMIN_ROLE, 0);
        _grantRole(DEFAULT_ADMIN_ROLE, pendingOwner());
        _grantRole(MINTER_ROLE, pendingOwner());
        _grantRole(PAUSER_ROLE, pendingOwner());
        _revokeRole(DEFAULT_ADMIN_ROLE, beforeOwner);
        _revokeRole(MINTER_ROLE, beforeOwner);
        _revokeRole(PAUSER_ROLE, beforeOwner);
        super.acceptOwnership();
    }

    /*
     * @dev setFreeze
     */
    function setFreeze(address holder, bool status) public onlyOwner returns (bool) {
        require(holder != address(0), "SFZ01");
        bool beforeStatus = frozenAccount[holder];

        if (beforeStatus != status) {
            frozenAccount[holder] = status;
            if (status) emit Freeze(holder);
            else emit Unfreeze(holder);
        }
        return true;
    }

    /*
     * @dev - the caller must have the ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) public override(AccessControl, IAccessControl) {
        _beforeSetRole(role, account, false);
        super.revokeRole(role, account);
    }

    /*
     * @dev
     * - the caller must be the `account`.
     */
    function renounceRole(bytes32 role, address account) public override(AccessControl, IAccessControl) {
        _beforeSetRole(role, account, false);
        super.renounceRole(role, account);
    }

    /**
     * @dev Implement ERC-2771.
     * setForwarder makes the TokenForwarder's execute function work.
     */
    function setForwarder(address forwarder) public override(ERC2771) onlyOwner {
        require(forwarder.isContract(), "SFD01");
        super.setForwarder(forwarder);
    }

    /**
     * @dev grant role.
     *
     * Requirements:
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) public override(AccessControl, IAccessControl) {
        _beforeSetRole(role, account, true);
        super.grantRole(role, account);
    }

    /**
     * @dev Implement ERC-2612.
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public override(ERC20Permit) notFrozen(owner) whenNotPaused {
        super.permit(owner, spender, value, deadline, v, r, s);
    }

    function getRoleMembers(bytes32 role) public view returns (address[] memory members) {
        uint256 length = getRoleMemberCount(role);
        members = new address[](length);
        for (uint256 i = 0; i < length; i++) members[i] = getRoleMember(role, i);
    }

    /*
     * @dev Implement ERC-2612.
     */
    function getNonce(address from) public view returns (uint256) {
        return super.nonces(from);
    }

    /*
     * @dev Disable renounceOwnership
     */
    function renounceOwnership() public pure override {
        revert("Disabled renounceOwnership");
    }

    /*
     * @dev As a policy,
     * A 'frozen from address' cannot approve.
     */
    function _approve(address owner, address spender, uint256 amount) internal override {
        _beforeTokenTransaction(owner, spender, amount);
        super._approve(owner, spender, amount);
    }

    /*
     * @dev As a policy,
     * 'frozen from address' cannot transfer.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20PresetMinterPauser) notFrozen(from) {
        super._beforeTokenTransfer(from, to, amount);
    }

    /*
     * @dev As a policy,
     * 'frozen from address' cannot approve and transfer.
     */
    function _beforeTokenTransaction(address from, address to, uint256 amount) internal {
        _beforeTokenTransfer(from, to, amount);
    }

    function _checkFrozen(address holder) internal view {
        if (frozenAccount[holder]) {
            revert FrozenAccount(holder);
        }
    }

    /**
     * @dev ERC-2771 Override.
     */
    function _msgSender() internal view override(Context, ERC2771) returns (address) {
        return ERC2771._msgSender();
    }

    /*
     * @dev
     * Requirements:
     * - Check that the target is not a null address.
     * - Role can not DEFAULT_ADMIN_ROLE
     * - Maximum limit on the number of members.
     */
    function _beforeSetRole(bytes32 role, address target, bool maxMemberCheck) internal view {
        require(role != DEFAULT_ADMIN_ROLE, "_BSR01");
        require(target != address(0), "_BSR02");
        if (maxMemberCheck) {
            require(getRoleMemberCount(role) < 50, "_BSR03");
        }
    }
}
