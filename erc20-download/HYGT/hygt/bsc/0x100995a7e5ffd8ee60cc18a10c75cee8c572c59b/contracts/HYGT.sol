// SPDX-License-Identifier: GNU GPLv3

pragma solidity 0.8.19;

import "./interfaces/IHYGT.sol";

import "./utils/AccessControl.sol";
import "./utils/ERC20Permit.sol";

contract HYGT is IHYGT, AccessControl, ERC20Permit {

    /* ========== STATE VARIABLES ========== */

    bytes32 public constant LOCKER_ROLE = keccak256(abi.encodePacked("Locker"));
    bytes32 public constant CALLER_ROLE = keccak256(abi.encodePacked("Caller"));

    /// @dev Fixed time duration variables.
    uint128 private constant ONE_MONTH_TIME = 2592000;

    /// @dev Maximum Total Supply that can be minted - 1 Billion Tokens.
    /// Token allocation.
    /// 20% Team (36 month linear lockup).
    /// 40% Treasury (36 month linear lockup).
    /// 20% Treasury (unlocked initially).
    /// 20% Callers (reserved).
    uint256 private constant _maxTotalSupply = 1000000000 * 1e18;

    /// @dev Initialization variables.
    address private immutable _initializer;
    bool private _isInitialized;

    /* ========== STORAGE ========== */

    /// @notice Variables for lockup.
    struct Lock {
        bool status;
        uint256 unlockedAmount;
        uint256 totalAmount;
        uint256 startTime;
        uint256 intervalCounter;
        uint256 totalIntervals;
    }

    /// @notice A checkpoint for marking number of votes from a given block.
    struct Checkpoint {
        uint256 fromBlock;
        uint256 votes;
    }

    mapping (address => Lock) public lockups;
    mapping (address => mapping (uint256 => Checkpoint)) public checkpoints;
    mapping (address => uint256) public numCheckpoints;
    mapping (address => address) public delegates;

    /* ========== EVENTS ========== */

    event Unlock(address indexed locker, uint256 unlockedAmount, uint256 intervalCounter);
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);

    /* ========== CONSTRUCTOR ========== */

    /**
     * @notice Setting max total supply and minting initial supply at contract creation.
     * @param team_ The address of the `Team` wallet.
     * @param treasury_ The address of the `Treasury` wallet.
     */
    constructor(address team_, address treasury_)
        ERC20("High Yield Dollar Governance Token", "HYGT")
        ERC20Permit("High Yield Dollar Governance Token")
    {
        require(team_ != address(0), "HYGT: invalid Team address");
        require(treasury_ != address(0), "HYGT: invalid Treasury address");
        _grantRole(LOCKER_ROLE, team_);
        _grantRole(LOCKER_ROLE, treasury_);
        /// @dev Renounce Role after setup is complete.
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());

        /// @dev 20% of Max Total Supply unlocked at contract creation to the treasury.
        uint256 toMint = (_maxTotalSupply * 20) / 100;
        _mint(treasury_, toMint);

        /// @dev starting lockups.
        uint256 teamLockAmount = (_maxTotalSupply * 20) / 100;
        uint256 treasuryLockAmount = (_maxTotalSupply * 40) / 100;
        _mint(address(this), teamLockAmount + treasuryLockAmount);

        Lock memory teamLock = Lock(true, 0, teamLockAmount, block.timestamp, 0, 36);
        Lock memory treasuryLock = Lock(true, 0, treasuryLockAmount, block.timestamp, 0, 36);
        lockups[team_] = teamLock;
        lockups[treasury_] = treasuryLock;

        _initializer = _msgSender();
    }

    /* ========== INITIALIZE ========== */

    /**
     * @notice Initializes external dependencies and state variables.
     * @dev This function can only be called once.
     * @param earn_ The address of the `Earn` contract.
     * @param farm_ The address of the `Farm` contract.
     */
    function initialize(address earn_, address farm_) external {
        require(_msgSender() == _initializer, "HYGT: caller is not the initializer");
        require(!_isInitialized, "HYGT: already initialized");

        require(earn_ != address(0), "HYGT: invalid Earn address");
        require(farm_ != address(0), "HYGT: invalid Farm address");
        _grantRole(CALLER_ROLE, earn_);
        _grantRole(CALLER_ROLE, farm_);

        _isInitialized = true;
    }

    /* ========== FUNCTIONS ========== */

    /**
     * @dev Returns the maximum amount of tokens that can exist.
     */
    function maxTotalSupply() external pure override returns (uint256) {
        return _maxTotalSupply;
    }

    /**
     * @notice Gets the current votes balance for `account`.
     * @param account The address to get votes balance.
     */
    function getCurrentVotes(address account) external view returns (uint256) {
        uint256 nCheckpoints = numCheckpoints[account];
        return nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
    }

    /**
     * @notice Determine the prior number of votes for an account as of a block number.
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param account The address of the account to check.
     * @param blockNumber The block number to get the vote balance at.
     */
    function getPriorVotes(address account, uint256 blockNumber) external view returns (uint256) {
        require(blockNumber < block.number, "HYGT: not yet determined");
        uint256 nCheckpoints = numCheckpoints[account];

        if (nCheckpoints == 0) {
            return 0;
        }
        /// @dev First check most recent balance
        if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
            return checkpoints[account][nCheckpoints - 1].votes;
        }
        /// @dev Next check implicit zero balance
        if (checkpoints[account][0].fromBlock > blockNumber) {
            return 0;
        }

        uint256 lower = 0;
        uint256 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint256 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[account][center];

            if (cp.fromBlock == blockNumber) {
                return cp.votes;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[account][lower].votes;
    }

    /**
     * @dev Unlocks vested tokens to their corresponding locker.
     */
    function unlock() external onlyRole(LOCKER_ROLE) {
        Lock storage lock = lockups[_msgSender()];

        require(lock.status, "HYGT: invalid lock");
        uint256 lastUnlockTime = lock.startTime + (lock.intervalCounter * ONE_MONTH_TIME);
        uint256 maxIntervals = lock.totalIntervals - lock.intervalCounter;
        uint256 numberOfIntervals = (block.timestamp - lastUnlockTime) / ONE_MONTH_TIME;
        numberOfIntervals = numberOfIntervals > maxIntervals ? maxIntervals : numberOfIntervals;

        require(numberOfIntervals > 0, "HYGT: no intervals have passed yet");
        uint256 unlockAmount = (lock.totalAmount * numberOfIntervals) / lock.totalIntervals;
        lock.unlockedAmount += unlockAmount;
        lock.intervalCounter += numberOfIntervals;

        if (lock.intervalCounter == lock.totalIntervals) {
            /// @dev This addition is to correct for errors caused by solidity division.
            unlockAmount += lock.totalAmount - lock.unlockedAmount;
            lock.status = false;
        }
        _transfer(address(this), _msgSender(), unlockAmount);

        emit Unlock(_msgSender(), lock.unlockedAmount, lock.intervalCounter);
    }

    /**
     * @dev See {ERC20-_mint}.
     *
     * Requirements:
     *
     * - the caller must have the `Caller` role.
     * - `amount` must not cause `_totalSupply` to exceed `_maxTotalSupply`.
     */
    function mint(address to, uint256 amount) external override onlyRole(CALLER_ROLE) returns (bool) {
        _mint(to, amount);

        require(totalSupply() <= _maxTotalSupply, "HYGT: invalid amount considering max total supply");
        return true;
    }

    /**
     * @dev See {ERC20-_burn}.
     */
    function burn(uint256 amount) external override returns (bool) {
        address owner = _msgSender();
        _burn(owner, amount);
        return true;
    }

    /**
     * @dev Destorys `amount` tokens from `from` using the allowance
     * mechanism. `amount` is then deducted from the caller's allowance.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least `amount`.
     */
    function burnFrom(address from, uint256 amount) external override onlyRole(CALLER_ROLE) returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _burn(from, amount);
        return true;
    }

    /**
     * @notice Delegate votes from `_msgSender()` to `delegatee`.
     * @param delegatee The address to delegate votes to.
     */
    function delegate(address delegatee) external {
        return _delegate(_msgSender(), delegatee);
    }

    function _delegate(address delegator, address delegatee) internal {
        address currentDelegate = delegates[delegator];
        uint256 delegatorBalance = balanceOf(delegator);
        delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveDelegates(currentDelegate, delegatee, delegatorBalance);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        // Ensuring delegation moves when token is transferred.
        _moveDelegates(delegates[from], delegates[to], amount);
    }

    function _moveDelegates(
        address srcRep,
        address dstRep,
        uint256 amount
    ) internal {
        if (srcRep != dstRep && amount > 0) {
            if (srcRep != address(0)) {
                uint256 srcRepNum = numCheckpoints[srcRep];
                uint256 srcRepOld = srcRepNum > 0 ? checkpoints[srcRep][srcRepNum - 1].votes : 0;
                uint256 srcRepNew = srcRepOld - amount;
                _writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew);
            }
            if (dstRep != address(0)) {
                uint256 dstRepNum = numCheckpoints[dstRep];
                uint256 dstRepOld = dstRepNum > 0 ? checkpoints[dstRep][dstRepNum - 1].votes : 0;
                uint256 dstRepNew = dstRepOld + amount;
                _writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew);
            }
        }
    }

    function _writeCheckpoint(
        address delegatee,
        uint256 nCheckpoints,
        uint256 oldVotes,
        uint256 newVotes
    ) internal {
        if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].fromBlock == block.number) {
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else {
            checkpoints[delegatee][nCheckpoints] = Checkpoint(block.number, newVotes);
            numCheckpoints[delegatee] = nCheckpoints + 1;
        }

        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }
}