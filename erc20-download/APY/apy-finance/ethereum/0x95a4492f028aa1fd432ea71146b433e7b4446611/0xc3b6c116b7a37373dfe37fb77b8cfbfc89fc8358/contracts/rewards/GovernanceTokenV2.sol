// SPDX-License-Identifier: BUSDL-1.1
pragma solidity 0.6.11;
pragma experimental ABIEncoderV2;

import {
    OwnableUpgradeSafe
} from "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import {
    Initializable
} from "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import {
    ERC20UpgradeSafe
} from "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";

import {EnumerableSet} from "contracts/libraries/Imports.sol";
import {SafeMath as SafeMathUpgradeSafe} from "contracts/proxy/Imports.sol";
import {ITimeLocked} from "./ITimeLocked.sol";

contract GovernanceTokenV2 is
    Initializable,
    OwnableUpgradeSafe,
    ERC20UpgradeSafe,
    ITimeLocked
{
    using SafeMathUpgradeSafe for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    /* ------------------------------- */
    /* impl-specific storage variables */
    /* ------------------------------- */
    // V1
    address public proxyAdmin;

    // V2
    /** @notice expiry of timelock in unix time */
    uint256 public override lockEnd;
    /** @dev addresses allowed to timelock user balances */
    EnumerableSet.AddressSet private _lockers;
    /** @dev amounts locked per user */
    mapping(address => uint256) private _lockedAmount;

    /* ------------------------------- */

    event AdminChanged(address);

    modifier onlyAdmin() {
        require(msg.sender == proxyAdmin, "ADMIN_ONLY");
        _;
    }

    modifier onlyLocker() {
        require(isLocker(msg.sender), "LOCKER_ONLY");
        _;
    }

    receive() external payable {
        revert("DONT_SEND_ETHER");
    }

    /** @dev V1 init, copied unchanged from V1 contract */
    function initialize(address adminAddress, uint256 totalSupply)
        external
        initializer
    {
        require(adminAddress != address(0), "INVALID_ADMIN");

        // initialize ancestor storage
        __Context_init_unchained();
        __Ownable_init_unchained();
        __ERC20_init_unchained("APY Governance Token", "APY");

        // initialize impl-specific storage
        setAdminAddress(adminAddress);

        _mint(msg.sender, totalSupply);
    }

    // solhint-disable-next-line no-empty-blocks
    function initializeUpgrade() external virtual onlyAdmin {}

    /**
     * @notice Set the time-lock expiry for all locked balances.
     * @param lockEnd_ time-lock expiry
     *
     * @dev It is possible to terminate the lock early  by setting `lockEnd` to a past
     * time, e.g. 0.
     *
     * Resetting `lockEnd` to another future time is also possible.  This may be useful
     * if the end of the time-lock needs to be reconsidered.
     *
     * WARNING: starting another lock after one has expired can cause issues.  The
     * time-lock functionality is only meant to be used once, during which it can be
     * extended or ended early, as mentioned above.  Creating a time-lock after APY
     * transfers have happened could result in reverts for some users.
     */
    function setLockEnd(uint256 lockEnd_) external override onlyOwner {
        lockEnd = lockEnd_;
    }

    /**
     * @notice Allow account to time-lock user balances.
     * @param account address to give locking privilege
     */
    function addLocker(address account) external override onlyOwner {
        _lockers.add(account);
        emit LockerAdded(account);
    }

    /**
     * @notice Remove account from allowed lockers
     * @param locker address to no longer allow locking privilege
     */
    function removeLocker(address locker) external override onlyOwner {
        _lockers.remove(locker);
        emit LockerRemoved(locker);
    }

    /**
     * @notice Time-lock specified amount of account's balance.
     * @param account address which will have its balance locked
     * @param amount amount of balance to be locked
     */
    function lockAmount(address account, uint256 amount)
        external
        override
        onlyLocker
    {
        require(isLockPeriodActive(), "LOCK_PERIOD_INACTIVE");
        require(
            amount <= unlockedBalance(account),
            "AMOUNT_EXCEEDS_UNLOCKED_BALANCE"
        );
        _lockedAmount[account] = _lockedAmount[account].add(amount);
    }

    function setAdminAddress(address adminAddress) public onlyOwner {
        require(adminAddress != address(0), "INVALID_ADMIN");
        proxyAdmin = adminAddress;
        emit AdminChanged(adminAddress);
    }

    /**
     * @notice Returns the portion of account balance that is not time-locked.
     * @param account the user address
     * @return amount Unlocked portion of user balance
     */
    function unlockedBalance(address account)
        public
        view
        override
        returns (uint256 amount)
    {
        if (isLockPeriodActive()) {
            amount = balanceOf(account).sub(_lockedAmount[account]);
        } else {
            amount = balanceOf(account);
        }
    }

    /**
     * @notice Returns true if lock period is active.
     */
    function isLockPeriodActive() public view override returns (bool) {
        // solhint-disable-next-line not-rely-on-time
        return block.timestamp <= lockEnd;
    }

    /** @notice Check if account is allowed to time-lock.
     * @param account account to check
     * @return true if allowed to lock, else false
     */
    function isLocker(address account) public view override returns (bool) {
        return _lockers.contains(account);
    }

    /**
     * @dev This hook will block transfers until block timestamp
     * is past `lockEnd`.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._beforeTokenTransfer(from, to, amount);
        require(
            from == address(0) || amount <= unlockedBalance(from),
            "LOCKED_BALANCE"
        );
    }
}
