// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlEnumerableUpgradeable} from
    "openzeppelin-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import {Math} from "openzeppelin/utils/math/Math.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20Upgradeable} from "openzeppelin-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import {ProtocolEvents} from "./interfaces/ProtocolEvents.sol";
import {IDepositContract} from "./interfaces/IDepositContract.sol";
import {IMETH} from "./interfaces/IMETH.sol";
import {IOracleReadRecord, OracleRecord} from "./interfaces/IOracle.sol";
import {IPauserRead} from "./interfaces/IPauser.sol";
import {IStaking, IStakingReturnsWrite, IStakingInitiationRead} from "./interfaces/IStaking.sol";
import {UnstakeRequest, IUnstakeRequestsManager} from "./interfaces/IUnstakeRequestsManager.sol";

/// @notice Events emitted by the staking contract.
interface StakingEvents {
    /// @notice Emitted when a user stakes ETH and receives mETH.
    /// @param staker The address of the user staking ETH.
    /// @param ethAmount The amount of ETH staked.
    /// @param mETHAmount The amount of mETH received.
    event Staked(address indexed staker, uint256 ethAmount, uint256 mETHAmount);

    /// @notice Emitted when a user unstakes mETH in exchange for ETH.
    /// @param id The ID of the unstake request.
    /// @param staker The address of the user unstaking mETH.
    /// @param ethAmount The amount of ETH that the staker will receive.
    /// @param mETHLocked The amount of mETH that will be burned.
    event UnstakeRequested(uint256 indexed id, address indexed staker, uint256 ethAmount, uint256 mETHLocked);

    /// @notice Emitted when a user claims their unstake request.
    /// @param id The ID of the unstake request.
    /// @param staker The address of the user claiming their unstake request.
    event UnstakeRequestClaimed(uint256 indexed id, address indexed staker);

    /// @notice Emitted when a validator has been initiated (i.e. the protocol has deposited into the deposit contract).
    /// @param id The ID of the validator which is the hash of its pubkey.
    /// @param operatorID The ID of the node operator to which the validator belongs to.
    /// @param pubkey The pubkey of the validator.
    /// @param amountDeposited The amount of ETH deposited into the deposit contract for that validator.
    event ValidatorInitiated(bytes32 indexed id, uint256 indexed operatorID, bytes pubkey, uint256 amountDeposited);

    /// @notice Emitted when the protocol has allocated ETH to the UnstakeRequestsManager.
    /// @param amount The amount of ETH allocated to the UnstakeRequestsManager.
    event AllocatedETHToUnstakeRequestsManager(uint256 amount);

    /// @notice Emitted when the protocol has allocated ETH to use for deposits into the deposit contract.
    /// @param amount The amount of ETH allocated to deposits.
    event AllocatedETHToDeposits(uint256 amount);

    /// @notice Emitted when the protocol has received returns from the returns aggregator.
    /// @param amount The amount of ETH received.
    event ReturnsReceived(uint256 amount);
}

/// @title Staking
/// @notice Manages stake and unstake requests by users, keeps track of the total amount of ETH controlled by the
/// protocol, and initiates new validators.
contract Staking is Initializable, AccessControlEnumerableUpgradeable, IStaking, StakingEvents, ProtocolEvents {
    // Errors.
    error DoesNotReceiveETH();
    error InvalidConfiguration();
    error MaximumValidatorDepositExceeded();
    error MaximumMETHSupplyExceeded();
    error MinimumStakeBoundNotSatisfied();
    error MinimumUnstakeBoundNotSatisfied();
    error MinimumValidatorDepositNotSatisfied();
    error NotEnoughDepositETH();
    error NotEnoughUnallocatedETH();
    error NotReturnsAggregator();
    error NotUnstakeRequestsManager();
    error Paused();
    error PreviouslyUsedValidator();
    error ZeroAddress();
    error InvalidDepositRoot(bytes32);
    error StakeBelowMinimumMETHAmount(uint256 methAmount, uint256 expectedMinimum);
    error UnstakeBelowMinimumETHAmount(uint256 ethAmount, uint256 expectedMinimum);

    error InvalidWithdrawalCredentialsWrongLength(uint256);
    error InvalidWithdrawalCredentialsNotETH1(bytes12);
    error InvalidWithdrawalCredentialsWrongAddress(address);

    /// @notice Role allowed trigger administrative tasks such as allocating funds to / withdrawing surplusses from the
    /// UnstakeRequestsManager and setting various parameters on the contract.
    bytes32 public constant STAKING_MANAGER_ROLE = keccak256("STAKING_MANAGER_ROLE");

    /// @notice Role allowed to allocate funds to unstake requests manager and reserve funds to deposit into the
    /// validators.
    bytes32 public constant ALLOCATOR_SERVICE_ROLE = keccak256("ALLOCATER_SERVICE_ROLE");

    /// @notice Role allowed to initiate new validators by sending funds from the allocatedETHForDeposits balance
    /// to the beacon chain deposit contract.
    bytes32 public constant INITIATOR_SERVICE_ROLE = keccak256("INITIATOR_SERVICE_ROLE");

    /// @notice Role to manage the staking allowlist.
    bytes32 public constant STAKING_ALLOWLIST_MANAGER_ROLE = keccak256("STAKING_ALLOWLIST_MANAGER_ROLE");

    /// @notice Role allowed to stake ETH when allowlist is enabled.
    bytes32 public constant STAKING_ALLOWLIST_ROLE = keccak256("STAKING_ALLOWLIST_ROLE");

    /// @notice Role allowed to top up the unallocated ETH in the protocol.
    bytes32 public constant TOP_UP_ROLE = keccak256("TOP_UP_ROLE");

    /// @notice Payload struct submitted for validator initiation.
    /// @dev See also {initiateValidatorsWithDeposits}.
    struct ValidatorParams {
        uint256 operatorID;
        uint256 depositAmount;
        bytes pubkey;
        bytes withdrawalCredentials;
        bytes signature;
        bytes32 depositDataRoot;
    }

    /// @notice Keeps track of already initiated validators.
    /// @dev This is tracked to ensure that we never deposit for the same validator public key twice, which is a base
    /// assumption of this contract and the related off-chain accounting.
    mapping(bytes pubkey => bool exists) public usedValidators;

    /// @inheritdoc IStakingInitiationRead
    /// @dev This is needed to account for ETH that is still in flight, i.e. that has been sent to the deposit contract
    /// but has not been processed by the beacon chain yet. Once the off-chain oracle detects those deposits, they are
    /// recorded as `totalDepositsProcessed` in the oracle contract to avoid double counting. See also
    /// {totalControlled}.
    uint256 public totalDepositedInValidators;

    /// @inheritdoc IStakingInitiationRead
    uint256 public numInitiatedValidators;

    /// @notice The amount of ETH that is used to allocate to deposits and fill the pending unstake requests.
    uint256 public unallocatedETH;

    /// @notice The amount of ETH that is used deposit into validators.
    uint256 public allocatedETHForDeposits;

    /// @notice The minimum amount of ETH users can stake.
    uint256 public minimumStakeBound;

    /// @notice The minimum amount of mETH users can unstake.
    uint256 public minimumUnstakeBound;

    /// @notice When staking on Ethereum, validators must go through an entry queue to bring money into the system, and
    /// an exit queue to bring it back out. The entry queue increases in size as more people want to stake. While the
    /// money is in the entry queue, it is not earning any rewards. When a validator is active, or in the exit queue, it
    /// is earning rewards. Once a validator enters the entry queue, the only way that the money can be retrieved is by
    /// waiting for it to become active and then to exit it again. As of July 2023, the entry queue is approximately 40
    /// days and the exit queue is 0 days (with ~6 days of processing time).
    ///
    /// In a non-optimal scenario for the protocol, a user could stake (for example) 32 ETH to receive mETH, wait
    /// until a validator enters the queue, and then request to unstake to recover their 32 ETH. Now we have 32 ETH in
    /// the system which affects the exchange rate, but is not earning rewards.
    ///
    /// In this case, the 'fair' thing to do would be to make the user wait for the queue processing to finish before
    /// returning their funds. Because the tokens are fungible however, we have no way of matching 'pending' stakes to a
    /// particular user. This means that in order to fulfill unstake requests quickly, we must exit a different
    /// validator to return the user's funds. If we exit a validator, we can return the funds after ~5 days, but the
    /// original 32 ETH will not be earning for another 35 days, leading to a small but repeatable socialised loss of
    /// efficiency for the protocol. As we can only exit validators in chunks of 32 ETH, this case is also exacerbated
    /// by a user unstaking smaller amounts of ETH.
    ///
    /// To compensate for the fact that these two queues differ in length, we apply an adjustment to the exchange rate
    /// to reflect the difference and mitigate its effect on the protocol. This protects the protocol from the case
    /// above, and also from griefing attacks following the same principle. Essentially, when you stake you are
    /// receiving a value of mETH that discounts ~35 days worth of rewards in return for being able to access your
    /// money without waiting the full 40 days when unstaking. As the adjustment is applied to the exchange rate, this
    /// results in a small 'improvement' to the rate for all existing stakers (i.e. it is not a fee levied by the
    /// protocol itself).
    ///
    /// As the adjustment is applied to the exchange rate, the result is reflected in any user interface which shows the
    /// amount of mETH received when staking, meaning there is no surprise for users when staking or unstaking.
    /// @dev The value is in basis points (1/10000).
    uint16 public exchangeAdjustmentRate;

    /// @dev A basis point (often denoted as bp, 1bp = 0.01%) is a unit of measure used in finance to describe
    /// the percentage change in a financial instrument. This is a constant value set as 10000 which represents
    /// 100% in basis point terms.
    uint16 internal constant _BASIS_POINTS_DENOMINATOR = 10_000;

    /// @notice The maximum amount the exchange adjustment rate (10%) that can be set by the admin.
    uint16 internal constant _MAX_EXCHANGE_ADJUSTMENT_RATE = _BASIS_POINTS_DENOMINATOR / 10; // 10%

    /// @notice The minimum amount of ETH that the staking contract can send to the deposit contract to initiate new
    /// validators.
    /// @dev This is used as an additional safeguard to prevent sending deposits that would result in non-activated
    /// validators (since we don't do top-ups), that would need to be exited again to get the ETH back.
    uint256 public minimumDepositAmount;

    /// @notice The maximum amount of ETH that the staking contract can send to the deposit contract to initiate new
    /// validators.
    /// @dev This is used as an additional safeguard to prevent sending too large deposits. While this is not a critical
    /// issue as any surplus >32 ETH (at the time of writing) will automatically be withdrawn again at some point, it is
    /// still undesireable as it locks up not-earning ETH for the duration of the round trip decreasing the efficiency
    /// of the protocol.
    uint256 public maximumDepositAmount;

    /// @notice The beacon chain deposit contract.
    /// @dev ETH will be sent there during validator initiation.
    IDepositContract public depositContract;

    /// @notice The mETH token contract.
    /// @dev Tokens will be minted / burned during staking / unstaking.
    IMETH public mETH;

    /// @notice The oracle contract.
    /// @dev Tracks ETH on the beacon chain and other accounting relevant quantities.
    IOracleReadRecord public oracle;

    /// @notice The pauser contract.
    /// @dev Keeps the pause state across the protocol.
    IPauserRead public pauser;

    /// @notice The contract tracking unstake requests and related allocation and claim operations.
    IUnstakeRequestsManager public unstakeRequestsManager;

    /// @notice The address to receive beacon chain withdrawals (i.e. validator rewards and exits).
    /// @dev Changing this variable will not have an immediate effect as all exisiting validators will still have the
    /// original value set.
    address public withdrawalWallet;

    /// @notice The address for the returns aggregator contract to push funds.
    /// @dev See also {receiveReturns}.
    address public returnsAggregator;

    /// @notice The staking allowlist flag which, when enabled, allows staking only for addresses in allowlist.
    bool public isStakingAllowlist;

    /// @inheritdoc IStakingInitiationRead
    /// @dev This will be used to give off-chain services a sensible point in time to start their analysis from.
    uint256 public initializationBlockNumber;

    /// @notice The maximum amount of mETH that can be minted during the staking process.
    /// @dev This is used as an additional safeguard to create a maximum stake amount in the protocol. As the protocol
    /// scales up this value will be increased to allow for more staking.
    uint256 public maximumMETHSupply;

    /// @notice Configuration for contract initialization.
    struct Init {
        address admin;
        address manager;
        address allocatorService;
        address initiatorService;
        address returnsAggregator;
        address withdrawalWallet;
        IMETH mETH;
        IDepositContract depositContract;
        IOracleReadRecord oracle;
        IPauserRead pauser;
        IUnstakeRequestsManager unstakeRequestsManager;
    }

    constructor() {
        _disableInitializers();
    }

    /// @notice Inititalizes the contract.
    /// @dev MUST be called during the contract upgrade to set up the proxies state.
    function initialize(Init memory init) external initializer {
        __AccessControlEnumerable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, init.admin);
        _grantRole(STAKING_MANAGER_ROLE, init.manager);
        _grantRole(ALLOCATOR_SERVICE_ROLE, init.allocatorService);
        _grantRole(INITIATOR_SERVICE_ROLE, init.initiatorService);
        // Intentionally does not set anyone as the TOP_UP_ROLE as it will only be granted
        // in the off-chance that the top up functionality is required.

        // Set up roles for the staking allowlist. Intentionally do not grant anyone the
        // STAKING_ALLOWLIST_MANAGER_ROLE as it will only be granted later.
        _setRoleAdmin(STAKING_ALLOWLIST_MANAGER_ROLE, STAKING_MANAGER_ROLE);
        _setRoleAdmin(STAKING_ALLOWLIST_ROLE, STAKING_ALLOWLIST_MANAGER_ROLE);

        mETH = init.mETH;
        depositContract = init.depositContract;
        oracle = init.oracle;
        pauser = init.pauser;
        returnsAggregator = init.returnsAggregator;
        unstakeRequestsManager = init.unstakeRequestsManager;
        withdrawalWallet = init.withdrawalWallet;

        minimumStakeBound = 0.1 ether;
        minimumUnstakeBound = 0.01 ether;
        minimumDepositAmount = 32 ether;
        maximumDepositAmount = 32 ether;
        isStakingAllowlist = true;
        initializationBlockNumber = block.number;

        // Set the maximum mETH supply to some sensible amount which is expected to be changed as the
        // protocol ramps up.
        maximumMETHSupply = 1024 ether;
    }

    /// @notice Interface for users to stake their ETH with the protocol. Note: when allowlist is enabled, only users
    /// with the allowlist can stake.
    /// @dev Mints the corresponding amount of mETH (relative to the stake's share in the total ETH controlled by the
    /// protocol) to the user.
    /// @param minMETHAmount The minimum amount of mETH that the user expects to receive in return.
    function stake(uint256 minMETHAmount) external payable {
        if (pauser.isStakingPaused()) {
            revert Paused();
        }

        if (isStakingAllowlist) {
            _checkRole(STAKING_ALLOWLIST_ROLE);
        }

        if (msg.value < minimumStakeBound) {
            revert MinimumStakeBoundNotSatisfied();
        }

        uint256 mETHMintAmount = ethToMETH(msg.value);
        if (mETHMintAmount + mETH.totalSupply() > maximumMETHSupply) {
            revert MaximumMETHSupplyExceeded();
        }
        if (mETHMintAmount < minMETHAmount) {
            revert StakeBelowMinimumMETHAmount(mETHMintAmount, minMETHAmount);
        }

        // Increment unallocated ETH after calculating the exchange rate to ensure
        // a consistent rate.
        unallocatedETH += msg.value;

        emit Staked(msg.sender, msg.value, mETHMintAmount);
        mETH.mint(msg.sender, mETHMintAmount);
    }

    /// @notice Interface for users to submit a request to unstake.
    /// @dev Transfers the specified amount of mETH to the staking contract and locks it there until it is burned on
    /// request claim. The staking contract must therefore be approved to move the user's mETH on their behalf.
    /// @param methAmount The amount of mETH to unstake.
    /// @param minETHAmount The minimum amount of ETH that the user expects to receive.
    /// @return The request ID.
    function unstakeRequest(uint128 methAmount, uint128 minETHAmount) external returns (uint256) {
        return _unstakeRequest(methAmount, minETHAmount);
    }

    /// @notice Interface for users to submit a request to unstake with an ERC20 permit.
    /// @dev Transfers the specified amount of mETH to the staking contract and locks it there until it is burned on
    /// request claim. The permit must therefore allow the staking contract to move the user's mETH on their behalf.
    /// @return The request ID.
    function unstakeRequestWithPermit(
        uint128 methAmount,
        uint128 minETHAmount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256) {
        SafeERC20Upgradeable.safePermit(mETH, msg.sender, address(this), methAmount, deadline, v, r, s);
        return _unstakeRequest(methAmount, minETHAmount);
    }

    /// @notice Processes a user's request to unstake by transferring the corresponding mETH to the staking contract
    /// and creating the request on the unstake requests manager.
    /// @param methAmount The amount of mETH to unstake.
    /// @param minETHAmount The minimum amount of ETH that the user expects to receive.
    function _unstakeRequest(uint128 methAmount, uint128 minETHAmount) internal returns (uint256) {
        if (pauser.isUnstakeRequestsAndClaimsPaused()) {
            revert Paused();
        }

        if (methAmount < minimumUnstakeBound) {
            revert MinimumUnstakeBoundNotSatisfied();
        }

        uint128 ethAmount = uint128(mETHToETH(methAmount));
        if (ethAmount < minETHAmount) {
            revert UnstakeBelowMinimumETHAmount(ethAmount, minETHAmount);
        }

        uint256 requestID =
            unstakeRequestsManager.create({requester: msg.sender, mETHLocked: methAmount, ethRequested: ethAmount});
        emit UnstakeRequested({id: requestID, staker: msg.sender, ethAmount: ethAmount, mETHLocked: methAmount});

        SafeERC20Upgradeable.safeTransferFrom(mETH, msg.sender, address(unstakeRequestsManager), methAmount);

        return requestID;
    }

    /// @notice Interface for users to claim their finalized and filled unstaking requests.
    /// @dev See also {UnstakeRequestsManager} for a more detailed explanation of finalization and request filling.
    function claimUnstakeRequest(uint256 unstakeRequestID) external {
        if (pauser.isUnstakeRequestsAndClaimsPaused()) {
            revert Paused();
        }
        emit UnstakeRequestClaimed(unstakeRequestID, msg.sender);
        unstakeRequestsManager.claim(unstakeRequestID, msg.sender);
    }

    /// @notice Returns the status of the request whether it is finalized and how much ETH has been filled.
    /// See also {UnstakeRequestsManager.requestInfo} for a more detailed explanation of finalization and request
    /// filling.
    /// @param unstakeRequestID The ID of the unstake request.
    /// @return bool indicating if the unstake request is finalized, and the amount of ETH that has been filled.
    function unstakeRequestInfo(uint256 unstakeRequestID) external view returns (bool, uint256) {
        return unstakeRequestsManager.requestInfo(unstakeRequestID);
    }

    /// @notice Withdraws any surplus from the unstake requests manager.
    /// @dev The request manager is expected to return the funds by pushing them using
    /// {receiveFromUnstakeRequestsManager}.
    function reclaimAllocatedETHSurplus() external onlyRole(STAKING_MANAGER_ROLE) {
        // Calls the receiveFromUnstakeRequestsManager() where we perform
        // the accounting.
        unstakeRequestsManager.withdrawAllocatedETHSurplus();
    }

    /// @notice Allocates ETH from the unallocatedETH balance to the unstake requests manager to fill pending requests
    /// and adds to the allocatedETHForDeposits balance that is used to initiate new validators.
    function allocateETH(uint256 allocateToUnstakeRequestsManager, uint256 allocateToDeposits)
        external
        onlyRole(ALLOCATOR_SERVICE_ROLE)
    {
        if (pauser.isAllocateETHPaused()) {
            revert Paused();
        }

        if (allocateToUnstakeRequestsManager + allocateToDeposits > unallocatedETH) {
            revert NotEnoughUnallocatedETH();
        }

        unallocatedETH -= allocateToUnstakeRequestsManager + allocateToDeposits;

        if (allocateToDeposits > 0) {
            allocatedETHForDeposits += allocateToDeposits;
            emit AllocatedETHToDeposits(allocateToDeposits);
        }

        if (allocateToUnstakeRequestsManager > 0) {
            emit AllocatedETHToUnstakeRequestsManager(allocateToUnstakeRequestsManager);
            unstakeRequestsManager.allocateETH{value: allocateToUnstakeRequestsManager}();
        }
    }

    /// @notice Initiates new validators by sending ETH to the beacon chain deposit contract.
    /// @dev Cannot initiate the same validator (public key) twice. Since BLS signatures cannot be feasibly verified on
    /// the EVM, the caller must carefully make sure that the sent payloads (public keys + signatures) are correct,
    /// otherwise the sent ETH will be lost.
    function initiateValidatorsWithDeposits(ValidatorParams[] calldata validators, bytes32 expectedDepositRoot)
        external
        onlyRole(INITIATOR_SERVICE_ROLE)
    {
        if (pauser.isInitiateValidatorsPaused()) {
            revert Paused();
        }
        if (validators.length == 0) {
            return;
        }

        // Check that the deposit root matches the given value. This ensures that the deposit contract state
        // has not changed since the transaction was submitted, which means that a rogue node operator cannot
        // front-run deposit transactions.
        bytes32 actualRoot = depositContract.get_deposit_root();
        if (expectedDepositRoot != actualRoot) {
            revert InvalidDepositRoot(actualRoot);
        }

        // First loop is to check that all validators are valid according to our constraints and we record the
        // validators and how much we have deposited.
        uint256 amountDeposited = 0;
        for (uint256 i = 0; i < validators.length; ++i) {
            ValidatorParams calldata validator = validators[i];

            if (usedValidators[validator.pubkey]) {
                revert PreviouslyUsedValidator();
            }

            if (validator.depositAmount < minimumDepositAmount) {
                revert MinimumValidatorDepositNotSatisfied();
            }

            if (validator.depositAmount > maximumDepositAmount) {
                revert MaximumValidatorDepositExceeded();
            }

            _requireProtocolWithdrawalAccount(validator.withdrawalCredentials);

            usedValidators[validator.pubkey] = true;
            amountDeposited += validator.depositAmount;

            emit ValidatorInitiated({
                id: keccak256(validator.pubkey),
                operatorID: validator.operatorID,
                pubkey: validator.pubkey,
                amountDeposited: validator.depositAmount
            });
        }

        if (amountDeposited > allocatedETHForDeposits) {
            revert NotEnoughDepositETH();
        }

        allocatedETHForDeposits -= amountDeposited;
        totalDepositedInValidators += amountDeposited;
        numInitiatedValidators += validators.length;

        // Second loop is to send the deposits to the deposit contract. Keeps external calls to the deposit contract
        // separate from state changes.
        for (uint256 i = 0; i < validators.length; ++i) {
            ValidatorParams calldata validator = validators[i];
            depositContract.deposit{value: validator.depositAmount}({
                pubkey: validator.pubkey,
                withdrawal_credentials: validator.withdrawalCredentials,
                signature: validator.signature,
                deposit_data_root: validator.depositDataRoot
            });
        }
    }

    /// @inheritdoc IStakingReturnsWrite
    /// @dev Intended to be the called in the same transaction initiated by reclaimAllocatedETHSurplus().
    /// This should only be called in emergency scenarios, e.g. if the unstake requests manager has cancelled
    /// unfinalized requests and there is a surplus balance.
    /// Adds the received funds to the unallocated balance.
    function receiveFromUnstakeRequestsManager() external payable onlyUnstakeRequestsManager {
        unallocatedETH += msg.value;
    }

    /// @notice Tops up the unallocated ETH balance to increase the amount of ETH in the protocol.
    /// @dev Bypasses the returns aggregator fee collection to inject ETH directly into the protocol.
    function topUp() external payable onlyRole(TOP_UP_ROLE) {
        unallocatedETH += msg.value;
    }

    /// @notice Converts from mETH to ETH using the current exchange rate.
    /// The exchange rate is given by the total supply of mETH and total ETH controlled by the protocol.
    function ethToMETH(uint256 ethAmount) public view returns (uint256) {
        // 1:1 exchange rate on the first stake.
        // Using `METH.totalSupply` over `totalControlled` to check if the protocol is in its bootstrap phase since
        // the latter can be manipulated, for example by transferring funds to the `ExecutionLayerReturnsReceiver`, and
        // therefore be non-zero by the time the first stake is made
        if (mETH.totalSupply() == 0) {
            return ethAmount;
        }

        // deltaMETH = (1 - exchangeAdjustmentRate) * (mETHSupply / totalControlled) * ethAmount
        // This rounds down to zero in the case of `(1 - exchangeAdjustmentRate) * ethAmount * mETHSupply <
        // totalControlled`.
        // While this scenario is theoretically possible, it can only be realised feasibly during the protocol's
        // bootstrap phase and if `totalControlled` and `mETHSupply` can be changed independently of each other. Since
        // the former is permissioned, and the latter is not permitted by the protocol, this cannot be exploited by an
        // attacker.
        return Math.mulDiv(
            ethAmount,
            mETH.totalSupply() * uint256(_BASIS_POINTS_DENOMINATOR - exchangeAdjustmentRate),
            totalControlled() * uint256(_BASIS_POINTS_DENOMINATOR)
        );
    }

    /// @notice Converts from ETH to mETH using the current exchange rate.
    /// The exchange rate is given by the total supply of mETH and total ETH controlled by the protocol.
    function mETHToETH(uint256 mETHAmount) public view returns (uint256) {
        // 1:1 exchange rate on the first stake.
        // Using `METH.totalSupply` over `totalControlled` to check if the protocol is in its bootstrap phase since
        // the latter can be manipulated, for example by transferring funds to the `ExecutionLayerReturnsReceiver`, and
        // therefore be non-zero by the time the first stake is made
        if (mETH.totalSupply() == 0) {
            return mETHAmount;
        }

        // deltaETH = (totalControlled / mETHSupply) * mETHAmount
        // This rounds down to zero in the case of `mETHAmount * totalControlled < mETHSupply`.
        // While this scenario is theoretically possible, it can only be realised feasibly during the protocol's
        // bootstrap phase and if `totalControlled` and `mETHSupply` can be changed independently of each other. Since
        // the former is permissioned, and the latter is not permitted by the protocol, this cannot be exploited by an
        // attacker.
        return Math.mulDiv(mETHAmount, totalControlled(), mETH.totalSupply());
    }

    /// @notice The total amount of ETH controlled by the protocol.
    /// @dev Sums over the balances of various contracts and the beacon chain information from the oracle.
    function totalControlled() public view returns (uint256) {
        OracleRecord memory record = oracle.latestRecord();
        uint256 total = 0;
        total += unallocatedETH;
        total += allocatedETHForDeposits;
        /// The total ETH deposited to the beacon chain must be decreased by the deposits processed by the off-chain
        /// oracle since it will be accounted for in the currentTotalValidatorBalance from that point onwards.
        total += totalDepositedInValidators - record.cumulativeProcessedDepositAmount;
        total += record.currentTotalValidatorBalance;
        total += unstakeRequestsManager.balance();
        return total;
    }

    /// @notice Checks if the given withdrawal credentials are a valid 0x01 prefixed withdrawal address.
    /// @dev See also
    /// https://github.com/ethereum/consensus-specs/blob/master/specs/phase0/validator.md#eth1_address_withdrawal_prefix
    function _requireProtocolWithdrawalAccount(bytes calldata withdrawalCredentials) internal view {
        if (withdrawalCredentials.length != 32) {
            revert InvalidWithdrawalCredentialsWrongLength(withdrawalCredentials.length);
        }

        // Check the ETH1_ADDRESS_WITHDRAWAL_PREFIX and that all other bytes are zero.
        bytes12 prefixAndPadding = bytes12(withdrawalCredentials[:12]);
        if (prefixAndPadding != 0x010000000000000000000000) {
            revert InvalidWithdrawalCredentialsNotETH1(prefixAndPadding);
        }

        address addr = address(bytes20(withdrawalCredentials[12:32]));
        if (addr != withdrawalWallet) {
            revert InvalidWithdrawalCredentialsWrongAddress(addr);
        }
    }

    /// @inheritdoc IStakingReturnsWrite
    /// @dev Adds the received funds to the unallocated balance.
    function receiveReturns() external payable onlyReturnsAggregator {
        emit ReturnsReceived(msg.value);
        unallocatedETH += msg.value;
    }

    /// @notice Ensures that the caller is the returns aggregator.
    modifier onlyReturnsAggregator() {
        if (msg.sender != returnsAggregator) {
            revert NotReturnsAggregator();
        }
        _;
    }

    /// @notice Ensures that the caller is the unstake requests manager.
    modifier onlyUnstakeRequestsManager() {
        if (msg.sender != address(unstakeRequestsManager)) {
            revert NotUnstakeRequestsManager();
        }
        _;
    }

    /// @notice Ensures that the given address is not the zero address.
    modifier notZeroAddress(address addr) {
        if (addr == address(0)) {
            revert ZeroAddress();
        }
        _;
    }

    /// @notice Sets the minimum amount of ETH users can stake.
    function setMinimumStakeBound(uint256 minimumStakeBound_) external onlyRole(STAKING_MANAGER_ROLE) {
        minimumStakeBound = minimumStakeBound_;
        emit ProtocolConfigChanged(
            this.setMinimumStakeBound.selector, "setMinimumStakeBound(uint256)", abi.encode(minimumStakeBound_)
        );
    }

    /// @notice Sets the minimum amount of mETH users can unstake.
    function setMinimumUnstakeBound(uint256 minimumUnstakeBound_) external onlyRole(STAKING_MANAGER_ROLE) {
        minimumUnstakeBound = minimumUnstakeBound_;
        emit ProtocolConfigChanged(
            this.setMinimumUnstakeBound.selector, "setMinimumUnstakeBound(uint256)", abi.encode(minimumUnstakeBound_)
        );
    }

    /// @notice Sets the staking adjust rate.
    function setExchangeAdjustmentRate(uint16 exchangeAdjustmentRate_) external onlyRole(STAKING_MANAGER_ROLE) {
        if (exchangeAdjustmentRate_ > _MAX_EXCHANGE_ADJUSTMENT_RATE) {
            revert InvalidConfiguration();
        }

        // even though this check is redundant with the one above, this function will be rarely used so we keep it as a
        // reminder for future upgrades that this must never be violated.
        assert(exchangeAdjustmentRate_ <= _BASIS_POINTS_DENOMINATOR);

        exchangeAdjustmentRate = exchangeAdjustmentRate_;
        emit ProtocolConfigChanged(
            this.setExchangeAdjustmentRate.selector,
            "setExchangeAdjustmentRate(uint16)",
            abi.encode(exchangeAdjustmentRate_)
        );
    }

    /// @notice Sets the minimum amount of ETH that the staking contract can send to the deposit contract to initiate
    /// new validators.
    function setMinimumDepositAmount(uint256 minimumDepositAmount_) external onlyRole(STAKING_MANAGER_ROLE) {
        minimumDepositAmount = minimumDepositAmount_;
        emit ProtocolConfigChanged(
            this.setMinimumDepositAmount.selector, "setMinimumDepositAmount(uint256)", abi.encode(minimumDepositAmount_)
        );
    }

    /// @notice Sets the maximum amount of ETH that the staking contract can send to the deposit contract to initiate
    /// new validators.
    function setMaximumDepositAmount(uint256 maximumDepositAmount_) external onlyRole(STAKING_MANAGER_ROLE) {
        maximumDepositAmount = maximumDepositAmount_;
        emit ProtocolConfigChanged(
            this.setMaximumDepositAmount.selector, "setMaximumDepositAmount(uint256)", abi.encode(maximumDepositAmount_)
        );
    }

    /// @notice Sets the maximumMETHSupply variable.
    /// Note: We intentionally allow this to be set lower than the current totalSupply so that the amount can be
    /// adjusted downwards by unstaking.
    /// See also {maximumMETHSupply}.
    function setMaximumMETHSupply(uint256 maximumMETHSupply_) external onlyRole(STAKING_MANAGER_ROLE) {
        maximumMETHSupply = maximumMETHSupply_;
        emit ProtocolConfigChanged(
            this.setMaximumMETHSupply.selector, "setMaximumMETHSupply(uint256)", abi.encode(maximumMETHSupply_)
        );
    }

    /// @notice Sets the address to receive beacon chain withdrawals (i.e. validator rewards and exits).
    /// @dev Changing this variable will not have an immediate effect as all exisiting validators will still have the
    /// original value set.
    function setWithdrawalWallet(address withdrawalWallet_)
        external
        onlyRole(STAKING_MANAGER_ROLE)
        notZeroAddress(withdrawalWallet_)
    {
        withdrawalWallet = withdrawalWallet_;
        emit ProtocolConfigChanged(
            this.setWithdrawalWallet.selector, "setWithdrawalWallet(address)", abi.encode(withdrawalWallet_)
        );
    }

    /// @notice Sets the staking allowlist flag.
    function setStakingAllowlist(bool isStakingAllowlist_) external onlyRole(STAKING_MANAGER_ROLE) {
        isStakingAllowlist = isStakingAllowlist_;
        emit ProtocolConfigChanged(
            this.setStakingAllowlist.selector, "setStakingAllowlist(bool)", abi.encode(isStakingAllowlist_)
        );
    }

    receive() external payable {
        revert DoesNotReceiveETH();
    }

    fallback() external payable {
        revert DoesNotReceiveETH();
    }
}
