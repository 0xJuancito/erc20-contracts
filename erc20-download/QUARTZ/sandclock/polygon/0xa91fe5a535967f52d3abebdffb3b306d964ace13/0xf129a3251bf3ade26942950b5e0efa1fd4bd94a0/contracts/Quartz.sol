// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "./interfaces/IQuartzGovernor.sol";
import "./interfaces/IQuartz.sol";
import "./interfaces/IChildToken.sol";

/**
 * Polygon version of our Quartz token, bridged from Ethereum
 *
 * @notice This token starts out with 0 supply. All minting is done by the
 * bridge's ChildChainManager when a cross-chain transaction is made
 *
 * @notice In addition to ERC20 functionalities, this contract also allows
 * holders to stake tokens, which grants them voting rights on `Governor`, or
 * the ability to delegate that power to another party
 */
contract Quartz is
    ERC20Upgradeable,
    AccessControlUpgradeable,
    IQuartz,
    IChildToken
{
    // Emitted when Quartz is staked
    event Staked(
        uint64 indexed id,
        address indexed owner,
        address indexed beneficiary,
        uint256 amount,
        uint64 maturationTime
    );

    // Emitted when Quartz is unstaked
    event Unstaked(
        uint64 indexed id,
        address indexed owner,
        address indexed beneficiary,
        uint256 amount
    );

    // Emitted when the delegatee of an account is changed
    event DelegateChanged(
        address indexed delegator,
        address indexed fromDelegate,
        address indexed toDelegate
    );

    // Emitted when voting power for an account is changed
    event DelegateVotesChanged(address indexed delegate, uint256 newBalance);

    // Emitted when the governor contract is changed
    event GovernorChanged(address indexed governor);

    // Emitted when the minimum stake period is updated
    event MinStakePeriodChanged(uint64 minStakePeriod);

    struct StakeInfo {
        address owner; // Owner who staked tokens
        address beneficiary; // Beneficiary who received vote rep
        uint256 amount; // Staked Quartz amount
        uint64 period; // Stake period in seconds
        uint64 maturationTimestamp; // Stake maturation timestamp
        bool active; // Indicates active after maturation time
    }

    // an update to voting power for an entity
    struct Checkpoint {
        uint32 fromBlock;
        uint256 votes;
    }

    // role required by Polygon PoS bridge to mint tokens when a cross-chain transaction happens
    // https://docs.polygon.technology/docs/develop/ethereum-polygon/pos/mapping-assets/
    bytes32 public constant DEPOSITOR_ROLE = keccak256("DEPOSITOR_ROLE");

    // governor contract instance
    IQuartzGovernor public governor;

    // total amount staked by an account, which corresponds to his total voting power
    // (including delegated power)
    mapping(address => uint256) public userVotesRep;

    // delegates for each account
    mapping(address => address) public delegates;

    // all checkpoints for all accounts
    mapping(address => mapping(uint32 => Checkpoint)) public checkpoints;

    // checkpoint counters for all accounts
    mapping(address => uint32) public numCheckpoints;

    // minimum period before tokens can be unstaked
    uint64 public minStakePeriod;

    // stakes counter
    uint64 public stakeLength;

    // All stakes infos
    mapping(uint64 => StakeInfo) public stakes;

    // Total staked amount
    uint256 public override totalStaked;

    /**
     * @param _minStakePeriod the initial minStakePeriod to set
     * @param _childChainManager ChildChainManager instance for Polygon PoS bridge
     */
    function initialize(uint64 _minStakePeriod, address _childChainManager)
        external
        initializer
    {
        minStakePeriod = _minStakePeriod;
        emit MinStakePeriodChanged(_minStakePeriod);

        require(
            _childChainManager != address(0),
            "QUARTZ: Child chain manager cannot be zero"
        );

        __ERC20_init("Sandclock", "QUARTZ");
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(DEPOSITOR_ROLE, _childChainManager);
    }

    //
    // Public API
    //

    /**
     * Sets the governor contract
     *
     * @notice Can only be called by a contract admin
     *
     * @notice Can only be called once
     *
     * @param _governor new Governor instance to use
     */
    function setGovernor(IQuartzGovernor _governor)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            address(_governor) != address(0),
            "QUARTZ: Governor cannot be zero"
        );
        require(
            address(governor) == address(0),
            "QUARTZ: Governor already set"
        );
        governor = _governor;
        emit GovernorChanged(address(_governor));
    }

    /**
     * Stake QUARTZ token to grant vote rep to beneficiary for a period.
     *
     * @param _amount Amount of QUARTZ to stake
     * @param _beneficiary Beneficiary account for this stake
     * @param _period minimum period before unstaking is possible
     */
    function stake(
        uint256 _amount,
        address _beneficiary,
        uint64 _period
    ) external {
        require(
            _beneficiary != address(0),
            "QUARTZ: Beneficiary cannot be 0x0"
        );
        require(_amount > 0, "QUARTZ: Amount must be greater than zero");
        require(
            _period >= minStakePeriod,
            "QUARTZ: Period must be greater than minimum"
        );

        _transfer(msg.sender, address(this), _amount);

        address _owner = msg.sender;
        uint64 _stakeId = stakeLength;
        uint64 _maturationTimestamp = _getBlockTimestamp() + _period;
        StakeInfo memory stakeInfo =
            StakeInfo({
                owner: _owner,
                beneficiary: _beneficiary,
                amount: _amount,
                period: _period,
                maturationTimestamp: _maturationTimestamp,
                active: true
            });
        stakes[_stakeId] = stakeInfo;

        userVotesRep[_beneficiary] += _amount;
        if (delegates[_beneficiary] == address(0)) {
            _delegate(_beneficiary, _beneficiary);
        } else {
            _moveDelegates(address(0), delegates[_beneficiary], _amount);
        }

        stakeLength += 1;
        totalStaked += _amount;
        emit Staked(
            _stakeId,
            _owner,
            _beneficiary,
            _amount,
            _maturationTimestamp
        );
    }

    /**
     * Unstakes an existing stake
     *
     * @param _stakeId ID of the stake to unstake
     */
    function unstake(uint64 _stakeId) external {
        require(_stakeId < stakeLength, "QUARTZ: Invalid id");
        StakeInfo storage stakeInfo = stakes[_stakeId];
        //slither-disable-next-line timestamp
        require(
            stakeInfo.maturationTimestamp <= _getBlockTimestamp(),
            "QUARTZ: Not ready to unstake"
        );
        require(stakeInfo.active, "QUARTZ: Already unstaked");
        require(stakeInfo.owner == msg.sender, "QUARTZ: Not owner");

        stakeInfo.active = false;
        userVotesRep[stakeInfo.beneficiary] -= stakeInfo.amount;
        totalStaked -= stakeInfo.amount;

        _moveDelegates(
            delegates[stakeInfo.beneficiary],
            address(0),
            stakeInfo.amount
        );

        _transfer(address(this), msg.sender, stakeInfo.amount);

        emit Unstaked(
            _stakeId,
            stakeInfo.owner,
            stakeInfo.beneficiary,
            stakeInfo.amount
        );
    }

    /**
     * @notice Delegate votes from `msg.sender` to `delegatee`
     *
     * @param delegatee The address to delegate votes to
     */
    function delegate(address delegatee) external {
        return _delegate(msg.sender, delegatee);
    }

    /**
     * Locks voting power in the governor contract. Used by the governor
     * contract when votes are cast, to lock them until the proposal is finished
     *
     * @notice Only callable by the governor contract
     *
     * @param user User to get votes from
     * @param amount How many votes to lock
     */
    function moveVotesToGovernor(address user, uint256 amount)
        external
        override
    {
        require(
            msg.sender == address(governor),
            "QUARTZ: only governor can call"
        );
        _moveDelegates(user, msg.sender, amount);
    }

    /**
     * Unlocks voting power from the governor contract. Used by the governor
     * contract when a proposal is finished, and all of its votes are unlocked
     *
     * @notice Only callable by the governor contract
     *
     * @param user User to get votes from
     * @param amount How many votes to unlock
     */
    function moveVotesFromGovernor(address user, uint256 amount)
        external
        override
    {
        require(
            msg.sender == address(governor),
            "QUARTZ: only governor can call"
        );
        _moveDelegates(msg.sender, user, amount);
    }

    /**
     * Gets the current votes balance for `account`
     *
     * @param account The address to get votes balance
     * @return The number of current votes for `account`
     */
    function getCurrentVotes(address account)
        external
        view
        override
        returns (uint256)
    {
        uint32 nCheckpoints = numCheckpoints[account];
        return
            nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
    }

    //
    // Polygon PoS Bridge API
    //

    /**
     * @notice called when token is deposited on root chain
     *
     * @dev Should be callable only by ChildChainManager
     * Should handle deposit by minting the required amount for user
     * Make sure minting is done only by this function
     *
     * @param _user user address for whom deposit is being done
     * @param _depositData abi encoded amount
     */
    function deposit(address _user, bytes calldata _depositData)
        external
        override
        onlyRole(DEPOSITOR_ROLE)
    {
        uint256 amount = abi.decode(_depositData, (uint256));
        _mint(_user, amount);
    }

    /**
     * @notice called when user wants to withdraw tokens back to root chain
     *
     * @dev Should burn user's tokens. This transaction will be verified when exiting on root chain
     *
     * @param _amount amount of tokens to withdraw
     */
    function withdraw(uint256 _amount) external override {
        _burn(_msgSender(), _amount);
    }

    //
    // Private logic
    //

    /**
     * Sets a new delegate for an account, overwriting any previously existing delegate
     *
     * @param delegator Account to delegate from
     * @param delegatee Account to delegate to
     */
    function _delegate(address delegator, address delegatee) internal {
        require(delegatee != address(0), "QUARTZ: delegatee cannot be 0x0");
        address currentDelegate = delegates[delegator];
        uint256 delegatorVotesRep = userVotesRep[delegator];
        delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveDelegates(currentDelegate, delegatee, delegatorVotesRep);
    }

    /**
     * Moves voting power from an old delegate to a new one
     *
     * @notice If no explicit delegate is registered, the account is actually
     * its own delegate so this function is always used when transfering voting
     * power
     *
     * @notice If not enough voting power exists on srcRep, we try to withdraw
     * votes from governor's executed or canceled proposals. If we still don't
     * have enough votes, and if dstRep is 0x0 (meaning we need to destroy
     * votes), we force governor to withdraw from active proposals as well,
     * until the target amount is reached
     *
     * @param srcRep Account from which to take votes. If 0x0, we're creating new voting power
     * @param dstRep Account which will receive votes. If 0x0, we're destroying voting power
     * @param amount Amount of votes to transfer
     */
    function _moveDelegates(
        address srcRep,
        address dstRep,
        uint256 amount
    ) internal {
        // if both addresses are the same, or amount == 0, this is ano-op
        if (srcRep != dstRep && amount > 0) {
            if (srcRep != address(0)) {
                // remove voting power from srcRep
                uint32 srcRepNum = numCheckpoints[srcRep];
                uint256 srcRepOld =
                    srcRepNum > 0
                        ? checkpoints[srcRep][srcRepNum - 1].votes
                        : 0;
                if (srcRepOld < amount) {
                    governor.withdrawRequiredVotes(
                        srcRep,
                        amount - srcRepOld,
                        dstRep == address(0)
                    );
                    srcRepNum = numCheckpoints[srcRep];
                    srcRepOld = srcRepNum > 0
                        ? checkpoints[srcRep][srcRepNum - 1].votes
                        : 0;
                }
                uint256 srcRepNew = srcRepOld - amount;
                _writeCheckpoint(srcRep, srcRepNum, srcRepNew);
            }

            if (dstRep != address(0)) {
                // add voting power to dstRep
                uint32 dstRepNum = numCheckpoints[dstRep];
                uint256 dstRepOld =
                    dstRepNum > 0
                        ? checkpoints[dstRep][dstRepNum - 1].votes
                        : 0;
                uint256 dstRepNew = dstRepOld + amount;
                _writeCheckpoint(dstRep, dstRepNum, dstRepNew);
            }
        }
    }

    /**
     * Writes a new checkpoint with updated voting power info for a given delegatee
     *
     * @param delegatee The delegatee account
     * @param nCheckpoints How many checkpoints already exist for this delegatee
     * @param newVotes new voting power for this delegatee
     */
    function _writeCheckpoint(
        address delegatee,
        uint32 nCheckpoints,
        uint256 newVotes
    ) internal {
        uint32 blockNumber =
            safe32(
                block.number,
                "Quartz::_writeCheckpoint: block number exceeds 32 bits"
            );
        if (
            //slither-disable-next-line incorrect-equality
            nCheckpoints > 0 &&
            checkpoints[delegatee][nCheckpoints - 1].fromBlock == blockNumber
        ) {
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else {
            checkpoints[delegatee][nCheckpoints] = Checkpoint(
                blockNumber,
                newVotes
            );
            numCheckpoints[delegatee] = nCheckpoints + 1;
        }

        emit DelegateVotesChanged(delegatee, newVotes);
    }

    /**
     * Safely casts uint256 to uint32, reverting if it doesn't fit
     *
     * @param n Number to check
     * @param errorMessage message to throw in case of error
     * @return the converted uint32
     */
    function safe32(uint256 n, string memory errorMessage)
        internal
        pure
        returns (uint32)
    {
        require(n < 2**32, errorMessage);
        return uint32(n);
    }

    /**
     * Updates the minimum period for new stakes
     *
     * @notice Only callable by contract admin
     *
     * @param _minStakePeriod new minumum period
     */
    function setMinStakePeriod(uint64 _minStakePeriod)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        minStakePeriod = _minStakePeriod;
        emit MinStakePeriodChanged(_minStakePeriod);
    }

    /**
     * Returns the current block timestamp as a uint64
     */
    function _getBlockTimestamp() private view returns (uint64) {
        return uint64(block.timestamp);
    }
}
