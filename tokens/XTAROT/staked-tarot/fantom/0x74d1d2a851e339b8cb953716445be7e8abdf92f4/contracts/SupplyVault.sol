// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./libraries/StringHelpers.sol";
import "./libraries/BorrowableHelpers.sol";
import "./interfaces/ISupplyVaultStrategy.sol";
import "./interfaces/ISupplyVault.sol";
import "./interfaces/IBorrowable.sol";

contract SupplyVault is ERC20, ISupplyVault, Ownable, Pausable, ReentrancyGuard {
    using Math for uint256;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using BorrowableHelpers for IBorrowable;
    using StringHelpers for string;

    uint256 constant MAX_BPS = 10_000;
    uint256 constant MIN_FEE_BPS = 0;
    uint256 constant MAX_FEE_BPS = MAX_BPS / 2;

    IERC20 public immutable override underlying;
    IBorrowable[] public override borrowables;
    struct BorrowableInfo {
        bool enabled;
        bool exists;
    }
    mapping(IBorrowable => BorrowableInfo) borrowableInfo;

    uint public constant GRACE_PERIOD = 14 days;
    uint public constant MIN_DELAY = 2 days;
    uint public constant MAX_DELAY = 30 days;

    ISupplyVaultStrategy public override strategy;
    ISupplyVaultStrategy public override pendingStrategy;
    uint256 public override pendingStrategyNotBefore;

    address public override reallocateManager;

    address public override feeTo;
    uint256 public override feeBps = (MAX_BPS * 10) / 100;

    uint256 checkpointBalance;

    constructor(
        IERC20 _underlying,
        ISupplyVaultStrategy _strategy,
        string memory _name,
        string memory _symbol
    )
        public
        ERC20(
            _name.orElse(string("Tarot ").append(ERC20(address(_underlying)).symbol()).append(" Supply Vault")),
            _symbol.orElse(string("t").append(ERC20(address(_underlying)).symbol()))
        )
    {
        underlying = _underlying;
        strategy = _strategy;

        _pause();
    }

    function _addBorrowable(address _address) private {
        // Strategy interprets argument and returns a borrowable
        IBorrowable borrowable = strategy.getBorrowable(_address);
        require(address(borrowable.underlying()) == address(underlying), "V:INVLD_UL");
        require(!borrowableInfo[borrowable].exists, "V:B_X");

        borrowableInfo[borrowable].exists = true;
        borrowableInfo[borrowable].enabled = true;
        borrowables.push(borrowable);

        emit AddBorrowable(address(borrowable));
    }

    function addBorrowable(address _address) external override onlyOwner nonReentrant {
        _addBorrowable(_address);
    }

    function addBorrowables(address[] calldata _addressList) external override onlyOwner nonReentrant {
        for (uint256 i = 0; i < _addressList.length; i++) {
            _addBorrowable(_addressList[i]);
        }
    }

    function indexOfBorrowable(IBorrowable borrowable) public view override returns (uint256) {
        uint256 numBorrowables = borrowables.length;
        for (uint256 i = 0; i < numBorrowables; i++) {
            if (borrowables[i] == borrowable) {
                return i;
            }
        }
        require(false, "V:B_NOT_FOUND");
    }

    function removeBorrowable(IBorrowable borrowable) external override onlyOwner nonReentrant {
        require(borrowables.length > 0, "V:NO_B");
        require(borrowableInfo[borrowable].exists, "V:NO_B");
        require(!borrowableInfo[borrowable].enabled, "V:B_E");
        require(borrowable.balanceOf(address(this)) == 0, "V:B_NOT_EMPTY");

        uint256 lastIndex = borrowables.length - 1;
        uint256 index = indexOfBorrowable(borrowable);

        borrowables[index] = borrowables[lastIndex];
        borrowables.pop();
        delete borrowableInfo[borrowable];

        emit RemoveBorrowable(address(borrowable));
    }

    function disableBorrowable(IBorrowable borrowable) external override onlyOwner nonReentrant {
        require(borrowableInfo[borrowable].exists, "V:B_X");
        require(borrowableInfo[borrowable].enabled, "V:B_DSBLD");

        borrowableInfo[borrowable].enabled = false;

        emit DisableBorrowable(address(borrowable));
    }

    function enableBorrowable(IBorrowable borrowable) external override onlyOwner nonReentrant {
        require(borrowableInfo[borrowable].exists, "V:B_X");
        require(!borrowableInfo[borrowable].enabled, "V:B_E");

        borrowableInfo[borrowable].enabled = true;

        emit EnableBorrowable(address(borrowable));
    }

    function unwindBorrowable(IBorrowable borrowable, uint256 borrowableAmount) external override onlyOwner {
        require(borrowableInfo[borrowable].exists, "V:B_X");
        require(!borrowableInfo[borrowable].enabled, "V:B_E");

        // Apply any outstanding fees and get the amount of underlying locked in the contract
        bool belowCheckpoint;
        {
            // NOTE: Checkpoint may be below total underlying
            uint256 totalUnderlying = _applyFee();
            belowCheckpoint = totalUnderlying < checkpointBalance;
        }

        if (borrowableAmount == 0) {
            // If value is zero then unwind the entire borrowable
            borrowableAmount = borrowable.balanceOf(address(this));
        }
        require(borrowableAmount > 0, "V:B_ZERO");

        uint256 borrowableAmountAsUnderlying = borrowable.underlyingValueOf(borrowableAmount);
        require(borrowableAmountAsUnderlying > 0, "V:U_ZERO");

        uint256 available = Math.min(borrowable.myUnderlyingBalance(), underlying.balanceOf(address(borrowable)));
        require(borrowableAmountAsUnderlying <= available, "V:NEED_B");

        uint256 underlyingBalanceBefore = underlying.balanceOf(address(this));
        IERC20(address(borrowable)).safeTransfer(address(borrowable), borrowableAmount);
        borrowable.redeem(address(this));
        uint256 underlyingAmount = underlying.balanceOf(address(this)).sub(underlyingBalanceBefore);

        if (belowCheckpoint) {
            // We were below the checkpoint prior to this unwinding so do not touch checkpoint
        } else {
            // Checkpoint matched beforehand so make sure it matches afterward
            _updateCheckpointBalance(_getTotalUnderlying());
        }

        emit UnwindBorrowable(address(borrowable), underlyingAmount, borrowableAmount);
    }

    function updatePendingStrategy(ISupplyVaultStrategy _newPendingStrategy, uint256 _notBefore)
        external
        override
        onlyOwner
        nonReentrant
    {
        if (address(_newPendingStrategy) == address(0)) {
            require(_notBefore == 0, "V:NOT_BEFORE");
        } else {
            require(address(_newPendingStrategy) != address(0), "V:INVLD_STRAT");
            require(_newPendingStrategy != strategy, "V:SAME_STRAT");
            require(_notBefore >= block.timestamp + MIN_DELAY, "V:TOO_SOON");
            require(_notBefore < block.timestamp + MAX_DELAY, "V:TOO_LATE");
        }
        pendingStrategy = _newPendingStrategy;
        pendingStrategyNotBefore = _notBefore;

        emit UpdatePendingStrategy(address(_newPendingStrategy), _notBefore);
    }

    function updateStrategy() external override onlyOwner nonReentrant {
        require(address(pendingStrategy) != address(0), "V:INVLD_STRAT");
        require(block.timestamp >= pendingStrategyNotBefore, "V:TOO_SOON");
        require(block.timestamp < pendingStrategyNotBefore + GRACE_PERIOD, "V:TOO_LATE");
        require(pendingStrategy != strategy, "V:SAME_STRAT");

        strategy = pendingStrategy;
        delete pendingStrategy;
        delete pendingStrategyNotBefore;

        emit UpdateStrategy(address(strategy));
    }

    function updateFeeBps(uint256 _newFeeBps) external override onlyOwner nonReentrant {
        require(_newFeeBps >= MIN_FEE_BPS && _newFeeBps <= MAX_FEE_BPS, "V:INVLD_FEE");

        _applyFee();
        feeBps = _newFeeBps;

        emit UpdateFeeBps(_newFeeBps);
    }

    function updateFeeTo(address _newFeeTo) external override onlyOwner nonReentrant {
        require(_newFeeTo != feeTo, "V:SAME_FEE_TO");

        _applyFee();
        feeTo = _newFeeTo;

        emit UpdateFeeTo(_newFeeTo);
    }

    function updateReallocateManager(address _newReallocateManager) external override onlyOwner nonReentrant {
        require(_newReallocateManager != reallocateManager, "V:REALLOC_MGR");

        reallocateManager = _newReallocateManager;

        emit UpdateReallocateManager(_newReallocateManager);
    }

    function pause() external override onlyOwner nonReentrant {
        _pause();
    }

    function unpause() external override onlyOwner nonReentrant {
        _unpause();
    }

    function getBorrowablesLength() external view override returns (uint256) {
        return borrowables.length;
    }

    function getBorrowableEnabled(IBorrowable borrowable) external view override returns (bool) {
        return borrowableInfo[borrowable].enabled;
    }

    function getBorrowableExists(IBorrowable borrowable) external view override returns (bool) {
        return borrowableInfo[borrowable].exists;
    }

    function getTotalUnderlying() external override nonReentrant returns (uint256 totalUnderlying) {
        totalUnderlying = _applyFee();
    }

    function _getTotalUnderlying() private returns (uint256 totalUnderlying) {
        totalUnderlying = underlying.balanceOf(address(this));

        uint256 numBorrowables = borrowables.length;
        for (uint256 i = 0; i < numBorrowables; i++) {
            IBorrowable borrowable = borrowables[i];
            totalUnderlying = totalUnderlying.add(borrowable.myUnderlyingBalance());
        }
    }

    function enter(uint256 _amount) external override whenNotPaused nonReentrant returns (uint256 share) {
        share = _enterWithToken(address(underlying), _amount);
    }

    function enterWithToken(address _tokenAddress, uint256 _tokenAmount)
        public
        override
        whenNotPaused
        nonReentrant
        returns (uint256 share)
    {
        share = _enterWithToken(_tokenAddress, _tokenAmount);
    }

    // Deposit underlying and mint supply vault tokens
    function _enterWithToken(address _tokenAddress, uint256 _tokenAmount) private returns (uint256 share) {
        require(_tokenAmount > 0, "V:TKN_ZERO");

        uint256 underlyingAmount;
        if (_tokenAddress == address(underlying)) {
            underlyingAmount = _tokenAmount;
        } else if (borrowableInfo[IBorrowable(_tokenAddress)].enabled) {
            // _tokenAddress is a valid Borrowable
            // _amount is in Borrowable
            underlyingAmount = IBorrowable(_tokenAddress).underlyingValueOf(_tokenAmount);
        } else {
            require(false, "V:INVLD_TKN");
        }
        require(underlyingAmount > 0, "V:U_ZERO");

        // Apply any outstanding fees and get the amount of underlying locked in the contract
        uint256 totalUnderlying = _applyFee();

        // After applying fees we must be exactly at checkpoint to continue
        require(totalUnderlying == checkpointBalance, "V:DEP_PAUSE");

        uint256 totalShares = totalSupply();

        if (totalShares == 0) {
            if (totalUnderlying == 0) {
                // If no shares exists, mint it 1:1 to the amount put in
                share = underlyingAmount;
            } else {
                // No shares but we have a non-zero balance of underlying so mint 1:1 including existing balance
                share = underlyingAmount.add(totalUnderlying);
            }
        } else {
            // Shares are non-zero but we have a zero balance of underlying
            // Cannot happen because checkpoint balance would have been above zero
            require(totalUnderlying > 0, "V:TU_ZERO");

            // Calculate and mint the amount of shares the underlying is worth.
            // The ratio will change overtime, as shares are burned/minted and underlying deposited + gained from fees / withdrawn.
            share = underlyingAmount.mul(totalShares).div(totalUnderlying);
        }
        mint(msg.sender, share);

        // Lock the underlying in the contract (does not support taxed tokens)
        IERC20(_tokenAddress).safeTransferFrom(msg.sender, address(this), _tokenAmount);

        // Directly update the checkpoint balance to the new watermark so that it is in sync when we call strategy.allocate()
        checkpointBalance = checkpointBalance.add(underlyingAmount);
        // At this point checkpointBalance == getTotalUnderlying()

        strategy.allocate(); // should not change total

        _updateCheckpointBalance(_getTotalUnderlying()); // force a sync after allocation

        emit Enter(msg.sender, _tokenAddress, _tokenAmount, underlyingAmount, share);
    }

    // Unlocks the staked + gained underlying and burns share
    function leave(uint256 _share) external override whenNotPaused nonReentrant returns (uint256 underlyingAmount) {
        require(_share > 0, "V:S_ZERO");

        // if total is above checkpoint then it should be >= checkpoint after
        // if total is below checkpoint then it should be <= checkpoint after

        // Apply any outstanding fees and get the amount of underlying locked in the contract
        uint256 totalUnderlyingBefore = _applyFee();
        // NOTE: Checkpoint may be below total underlying
        bool belowCheckpoint = totalUnderlyingBefore < checkpointBalance;

        // Gets the amount of share in existence
        uint256 totalShares = totalSupply();
        // _share must be positive so this also ensures that totalShares is positive
        require(_share <= totalShares, "V:INVLD_S");

        uint256 needUnderlyingAmount = _share.mul(totalUnderlyingBefore).div(totalShares);
        uint256 haveUnderlyingAmount = underlying.balanceOf(address(this));
        if (needUnderlyingAmount > haveUnderlyingAmount) {
            needUnderlyingAmount = needUnderlyingAmount.sub(haveUnderlyingAmount);
            strategy.deallocate(needUnderlyingAmount); // deallocate what we need
        }
        // After deallocation we will have at least _share/totalShares available as underlying

        // Update our total to reflect costs of unwinding
        uint256 totalUnderlying = _getTotalUnderlying();

        // Calculates the amount of underlying the shares is worth
        underlyingAmount = _share.mul(totalUnderlying).div(totalShares);
        require(underlyingAmount > 0, "V:ZERO_REDEEM");
        require(underlyingAmount <= underlying.balanceOf(address(this)), "V:BAD_STRAT_DEALLOC");

        {
            uint256 newCheckpointBalance;
            if (belowCheckpoint) {
                // Scale the checkpoint to match the new total
                // C = C * (S - s) / S;
                newCheckpointBalance = checkpointBalance.mul(totalShares.sub(_share)).div(totalShares);
            } else {
                // Checkpoint balance matched beforehand so make sure it matches afterward
                newCheckpointBalance = totalUnderlying.sub(underlyingAmount);
            }
            _updateCheckpointBalance(newCheckpointBalance);
        }

        burn(msg.sender, _share);
        underlying.safeTransfer(msg.sender, underlyingAmount);

        emit Leave(msg.sender, _share, underlyingAmount);
    }

    function _transferShareOfToken(
        address _token,
        uint256 _share,
        uint256 _totalShares
    ) private returns (uint256 transferredAmount) {
        uint256 totalAmount = IERC20(_token).balanceOf(address(this));
        if (totalAmount > 0) {
            transferredAmount = totalAmount.mul(_share).div(_totalShares);
            if (transferredAmount > 0) {
                IERC20(_token).safeTransfer(msg.sender, transferredAmount);
            }
        }
    }

    function leaveInKind(uint256 _share) external override nonReentrant {
        require(_share > 0, "V:S_ZERO");

        bool belowCheckpoint;
        {
            // NOTE: Checkpoint may be below total underlying
            uint256 totalUnderlying = _applyFee();
            belowCheckpoint = totalUnderlying < checkpointBalance;
        }
        uint256 totalShares = totalSupply();

        // _share must be positive so this also ensures that totalShares is positive
        require(_share <= totalShares, "V:INVLD_S");

        burn(msg.sender, _share);

        // Send share of underlying
        bool sentSomething = _transferShareOfToken(address(underlying), _share, totalShares) > 0;
        // Send share of each borrowable
        uint256 numBorrowables = borrowables.length;
        for (uint256 i = 0; i < numBorrowables; i++) {
            IBorrowable borrowable = borrowables[i];
            if (_transferShareOfToken(address(borrowable), _share, totalShares) > 0) {
                sentSomething = true;
            }
        }

        // Ensure we sent something
        require(sentSomething, "V:ZERO_AMOUNT");

        {
            uint256 newCheckpointBalance;
            if (belowCheckpoint) {
                // Scale the checkpoint to match the new total
                // C = C * (S - s) / S;
                newCheckpointBalance = checkpointBalance.mul(totalShares.sub(_share)).div(totalShares);
            } else {
                // Checkpoint balance matched beforehand so make sure it matches afterward
                newCheckpointBalance = _getTotalUnderlying();
            }
            _updateCheckpointBalance(newCheckpointBalance);
        }

        emit LeaveInKind(msg.sender, _share);
    }

    function reallocate(uint256 _share, bytes calldata _data) external override nonReentrant {
        require(msg.sender == owner() || msg.sender == reallocateManager, "V:NOT_AUTHORIZED");

        // Apply any outstanding fees and get the amount of underlying locked in the contract
        uint256 totalUnderlyingBefore = _applyFee();
        // NOTE: Checkpoint may be below total underlying
        bool belowCheckpoint = totalUnderlyingBefore < checkpointBalance;

        // Gets the amount of share in existence
        uint256 totalShares = totalSupply();
        // _share must be positive so this also ensures that totalShares is positive
        require(_share <= totalShares, "V:INVLD_S");

        uint256 underlyingAmount = _share.mul(totalUnderlyingBefore).div(totalShares);
        strategy.reallocate(underlyingAmount, _data);

        if (belowCheckpoint) {
            // no-op
        } else {
            // Checkpoint balance matched beforehand so make sure it matches afterward
            _updateCheckpointBalance(_getTotalUnderlying());
        }

        emit Reallocate(msg.sender, _share);
    }

    function allocateIntoBorrowable(IBorrowable borrowable, uint256 underlyingAmount) external override onlyStrategy {
        require(borrowableInfo[borrowable].enabled, "V:NOT_ENABLED");

        uint256 borrowableBalanceBefore = borrowable.balanceOf(address(this));
        underlying.safeTransfer(address(borrowable), underlyingAmount);
        borrowable.mint(address(this));
        uint256 borrowableAmount = borrowable.balanceOf(address(this)).sub(borrowableBalanceBefore);

        emit AllocateBorrowable(address(borrowable), underlyingAmount, borrowableAmount);
    }

    function deallocateFromBorrowable(IBorrowable borrowable, uint256 borrowableAmount) external override onlyStrategy {
        require(borrowableInfo[borrowable].exists, "V:NOT_EXISTS");

        uint256 underlyingBalanceBefore = underlying.balanceOf(address(this));
        IERC20(address(borrowable)).safeTransfer(address(borrowable), borrowableAmount);
        borrowable.redeem(address(this));
        uint256 underlyingAmount = underlying.balanceOf(address(this)).sub(underlyingBalanceBefore);

        emit DeallocateBorrowable(address(borrowable), borrowableAmount, underlyingAmount);
    }

    // returns the total amount of underlying an address has in the supply vault
    function underlyingBalanceForAccount(address _account)
        external
        override
        nonReentrant
        returns (uint256 underlyingBalance)
    {
        uint256 totalUnderlying = _applyFee();
        uint256 shareAmount = balanceOf(_account);
        uint256 totalShares = totalSupply();
        underlyingBalance = shareAmount.mul(totalUnderlying).div(totalShares);
    }

    // Returns how much underlying we get for a given amount of share
    function shareValuedAsUnderlying(uint256 _share)
        external
        override
        nonReentrant
        returns (uint256 underlyingAmount_)
    {
        uint256 totalUnderlying = _applyFee();
        uint256 totalShares = totalSupply();
        underlyingAmount_ = _share.mul(totalUnderlying).div(totalShares);
    }

    // Returns how much share we get for depositing a given amount of underlying
    function underlyingValuedAsShare(uint256 _underlyingAmount)
        external
        override
        nonReentrant
        returns (uint256 share_)
    {
        uint256 totalUnderlying = _applyFee();
        uint256 totalShares = totalSupply();

        if (totalShares == 0) {
            if (totalUnderlying == 0) {
                // If no shares exists, mint it 1:1 to the amount put in
                share_ = _underlyingAmount;
            } else {
                // No shares but we have a non-zero balance of underlying so mint 1:1 including existing balance
                share_ = _underlyingAmount.add(totalUnderlying);
            }
        } else {
            // Shares are non-zero but we have a zero balance of underlying
            // Cannot happen because checkpoint balance would have been above zero
            require(totalUnderlying > 0, "V:TU_ZERO");

            // Calculate and mint the amount of shares the underlying is worth.
            // The ratio will change overtime, as shares are burned/minted and underlying deposited + gained from fees / withdrawn.
            share_ = _underlyingAmount.mul(totalShares).div(totalUnderlying);
        }
    }

    function getSupplyRate() external override nonReentrant returns (uint256 supplyRate_) {
        if (address(strategy) == address(0)) {
            return 0;
        }
        return strategy.getSupplyRate();
    }

    function applyFee() external override nonReentrant {
        _applyFee();
    }

    function _updateCheckpointBalance(uint256 _newCheckpointBalance) private {
        checkpointBalance = _newCheckpointBalance;
        emit UpdateCheckpoint(_newCheckpointBalance);
    }

    // Apply fees and return back the total underlying
    function _applyFee() private returns (uint256 totalUnderlying) {
        totalUnderlying = _getTotalUnderlying();

        if (totalUnderlying > checkpointBalance) {
            if (feeTo != address(0)) {
                uint256 gain = totalUnderlying.sub(checkpointBalance);
                uint256 fee = gain.mul(feeBps).div(MAX_BPS); // fee < gain
                // gain >= fee * MAX_BPS / feeBps
                // totalBalance - gain >= 0
                // totalBalance - fee > 0

                // (gain * Fee%) * Supply / (U - (gain * Fee%))
                if (fee > 0) {
                    uint256 totalShares = totalSupply();
                    // X = F * S / (U - F)
                    uint256 feeShares = fee.mul(totalShares).div(totalUnderlying.sub(fee));
                    if (feeShares > 0) {
                        mint(feeTo, feeShares);

                        emit ApplyFee(feeTo, gain, fee, feeShares);
                    }
                }
            }

            // Update our fee collection checkpoint watermark
            _updateCheckpointBalance(totalUnderlying);
        }
    }

    modifier onlyStrategy() {
        require(msg.sender == address(strategy), "V:STRAT");
        _;
    }

    //////
    // Copied and modified from YAM code:
    // https://github.com/yam-finance/yam-protocol/blob/master/contracts/token/YAMGovernanceStorage.sol
    // https://github.com/yam-finance/yam-protocol/blob/master/contracts/token/YAMGovernance.sol
    // Which is copied and modified from COMPOUND:
    // https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/Comp.sol

    // A record of each accounts delegate
    mapping(address => address) internal _delegates;

    /// @notice A checkpoint for marking number of votes from a given block
    struct Checkpoint {
        uint32 fromBlock;
        uint256 votes;
    }

    /// @notice A record of votes checkpoints for each account, by index
    mapping(address => mapping(uint32 => Checkpoint)) public checkpoints;

    /// @notice The number of checkpoints for each account
    mapping(address => uint32) public numCheckpoints;

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice The EIP-712 typehash for the delegation struct used by the contract
    bytes32 public constant DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    // A record of states for signing / validating signatures
    mapping(address => uint) public nonces;

    /// @notice An event thats emitted when an account changes its delegate
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    /// @notice An event thats emitted when a delegate account's vote balance changes
    event DelegateVotesChanged(address indexed delegate, uint previousBalance, uint newBalance);

    function burn(address _from, uint256 _amount) private {
        _burn(_from, _amount);
        _moveDelegates(_delegates[_from], address(0), _amount);
    }

    function mint(address recipient, uint256 _amount) private {
        _mint(recipient, _amount);

        _initDelegates(recipient);

        _moveDelegates(address(0), _delegates[recipient], _amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        bool result = super.transferFrom(sender, recipient, amount); // Call parent hook

        _initDelegates(recipient);

        _moveDelegates(_delegates[sender], _delegates[recipient], amount);

        return result;
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        bool result = super.transfer(recipient, amount); // Call parent hook

        _initDelegates(recipient);

        _moveDelegates(_delegates[_msgSender()], _delegates[recipient], amount);

        return result;
    }

    // initialize delegates mapping of recipient if not already
    function _initDelegates(address recipient) internal {
        if (_delegates[recipient] == address(0)) {
            _delegates[recipient] = recipient;
        }
    }

    /**
     * @param delegator The address to get delegates for
     */
    function delegates(address delegator) external view override returns (address) {
        return _delegates[delegator];
    }

    /**
     * @notice Delegate votes from `msg.sender` to `delegatee`
     * @param delegatee The address to delegate votes to
     */
    function delegate(address delegatee) external override {
        return _delegate(msg.sender, delegatee);
    }

    /**
     * @notice Delegates votes from signatory to `delegatee`
     * @param delegatee The address to delegate votes to
     * @param nonce The contract state required to match the signature
     * @param expiry The time at which to expire the signature
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function delegateBySig(
        address delegatee,
        uint nonce,
        uint expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        bytes32 domainSeparator = keccak256(
            abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name())), getChainId(), address(this))
        );

        bytes32 structHash = keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry));

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "V::delegateBySig: invalid signature");
        require(nonce == nonces[signatory]++, "V::delegateBySig: invalid nonce");
        require(block.timestamp <= expiry, "V::delegateBySig: signature expired");
        return _delegate(signatory, delegatee);
    }

    /**
     * @notice Gets the current votes balance for `account`
     * @param account The address to get votes balance
     * @return The number of current votes for `account`
     */
    function getCurrentVotes(address account) external view override returns (uint256) {
        uint32 nCheckpoints = numCheckpoints[account];
        return nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
    }

    /**
     * @notice Determine the prior number of votes for an account as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param account The address of the account to check
     * @param blockNumber The block number to get the vote balance at
     * @return The number of votes the account had as of the given block
     */
    function getPriorVotes(address account, uint blockNumber) external view override returns (uint256) {
        require(blockNumber < block.number, "V::getPriorVotes: not yet determined");

        uint32 nCheckpoints = numCheckpoints[account];
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
            return checkpoints[account][nCheckpoints - 1].votes;
        }

        // Next check implicit zero balance
        if (checkpoints[account][0].fromBlock > blockNumber) {
            return 0;
        }

        uint32 lower = 0;
        uint32 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
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

    function _delegate(address delegator, address delegatee) internal {
        address currentDelegate = _delegates[delegator];
        uint256 delegatorBalance = balanceOf(delegator); // balance of underlying BOOs (not scaled);
        _delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveDelegates(currentDelegate, delegatee, delegatorBalance);
    }

    function _moveDelegates(
        address srcRep,
        address dstRep,
        uint256 amount
    ) internal {
        if (srcRep != dstRep && amount > 0) {
            if (srcRep != address(0)) {
                // decrease old representative
                uint32 srcRepNum = numCheckpoints[srcRep];
                uint256 srcRepOld = srcRepNum > 0 ? checkpoints[srcRep][srcRepNum - 1].votes : 0;
                uint256 srcRepNew = srcRepOld - amount;
                _writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew);
            }

            if (dstRep != address(0)) {
                // increase new representative
                uint32 dstRepNum = numCheckpoints[dstRep];
                uint256 dstRepOld = dstRepNum > 0 ? checkpoints[dstRep][dstRepNum - 1].votes : 0;
                uint256 dstRepNew = dstRepOld + amount;
                _writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew);
            }
        }
    }

    function _writeCheckpoint(
        address delegatee,
        uint32 nCheckpoints,
        uint256 oldVotes,
        uint256 newVotes
    ) internal {
        uint32 blockNumber = safe32(block.number, "V::_writeCheckpoint: block number exceeds 32 bits");

        if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].fromBlock == blockNumber) {
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else {
            checkpoints[delegatee][nCheckpoints] = Checkpoint(blockNumber, newVotes);
            numCheckpoints[delegatee] = nCheckpoints + 1;
        }

        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }

    function safe32(uint n, string memory errorMessage) internal pure returns (uint32) {
        require(n < 2**32, errorMessage);
        return uint32(n);
    }

    function getChainId() internal view returns (uint) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }
}
