// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "hardhat/console.sol";

/// @dev MCT is the governance token contract
/// @notice fixed supply token
contract MCT is ERC20, Ownable {
    /// @dev is the minimum number of required signatures
    uint256 private constant MINIMUM_REQUIRED_SIGNATURES = 2;

    /// @dev Timelock and Multi-signature wallet
    uint256 private constant TIMELOCK_DELAY = 48 hours;
    uint256 private constant CANCELLATION_DELAY = 72 hours;

    uint256 public constant MAX_SUPPLY = 6e9 * 1e18;
    uint256 public immutable START_TIME;

    uint256 public constant RESERVE_POOL_LOCKUP = 104 weeks;
    uint256 public constant TEAM_LOCKUP = 52 weeks;

    /// @dev allocation amounts
    uint256 public constant MINING_POOL_ALLOCATION = 3.6e9 * 1e18;
    uint256 public constant AIRDROP_ALLOCATION = 6e8 * 1e18;
    uint256 public constant RESERVE_POOL_ALLOCATION = 7.2e8 * 1e18;
    uint256 public constant OPERATIONAL_POOL_ALLOCATION = 4.2e8 * 1e18;
    uint256 public constant TEAM_ALLOCATION = 4.2e8 * 1e18;
    uint256 public constant INITIAL_SUPPLY_ALLOCATION = 0.6e8 * 1e18;
    uint256 public constant INVESTOR_ALLOCATION = 1.8e8 * 1e18;

    /// @dev Vesting periods
    uint256 public constant MINING_POOL_VESTING = 520;
    uint256 public constant AIRDROP_VESTING = 52;
    uint256 public constant RESERVE_POOL_VESTING = 104;
    uint256 public constant OPERATIONAL_POOL_VESTING = 156;
    uint256 public constant TEAM_VESTING = 156;

    /// @dev allowed pool allocation receivers
    address public constant MINING_POOL_RECEIVER =
        0xb54E1c4B3927f4489Ead5c149b7895ecd03a5CE0;
    address public constant AIRDROP_POOL_RECEIVER =
        0xF32fB437A2768f02FaDA4d97aBe76D8f306F44Fe;
    address public constant RESERVE_POOL_RECEIVER =
        0xd1e532C785deEC90c1c69c7c5A7DcD28a8f74248;
    address public constant OPERATIONAL_POOL_RECEIVER =
        0xA0B9Fe04F0E6E44E42C90CfE30507769E91C1919;
    address public constant TEAM_RECEIVER =
        0x8A83d34fa97910B0786d8dAB29C5F3ACA5C1Cc76;
    address public constant INITIAL_SUPPLY_RECEIVER =
        0x8824fE9FA03d3716A762375867FAC2052Cd54A8C;
    address public constant INVESTOR_POOL_RECEIVER =
        0x910bBe8B14dbe813eA3F0e268058b024Bf5301D9;

    mapping(uint256 => uint256) public poolLastClaimTime; // maps pool id to last claim time
    mapping(uint256 => uint256) public poolClaimedAmount; // maps pool id to total claim amount

    mapping(address => uint256) public investment;
    mapping(address => uint256) public investedAt;
    mapping(address => uint256) public investedAmountTransferred;

    address private signerToRemove;
    uint256 public signersCount;

    mapping(address => bool) public isSigner;
    mapping(uint256 => bool) private isOperationPending;
    mapping(uint256 => uint256) private operationTimestamp;
    mapping(uint256 => uint256) private operationApprovals;
    mapping(uint256 => address[]) private operationApprovalSigner;

    /// @dev A web link for sharing the timelock contract and multi-signers addresses information
    string public multiSigAddressesLink;

    /// @dev A web link for share the token distribution plan and multi-signature wallet address
    string public tokenDistributionPlanLink;

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/
    event TokenDistributionPlanUpdate(string newPlan);
    event MultiSignerAddressesUpdated(string addresses);
    event NewSignerAdded(address newSigner);
    event OldSignerRemoved(address oldSigner);

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Set the token distribution plan and multi-signature wallet address
    modifier onlySigner() {
        require(
            isSigner[msg.sender],
            "MCT: Only signers can call this function"
        );
        _;
    }

    modifier onlyAfterTimelock(uint256 operationId) {
        require(
            block.timestamp > operationTimestamp[operationId] + TIMELOCK_DELAY,
            "MCT: Timelock period not yet expired"
        );
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) {
        require(
            MINING_POOL_ALLOCATION +
                AIRDROP_ALLOCATION +
                RESERVE_POOL_ALLOCATION +
                OPERATIONAL_POOL_ALLOCATION +
                TEAM_ALLOCATION +
                INITIAL_SUPPLY_ALLOCATION +
                INVESTOR_ALLOCATION ==
                MAX_SUPPLY
        );
        START_TIME = block.timestamp;
    }

    /*//////////////////////////////////////////////////////////////
                        PREVILAGED METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev allows owner to add external link that contains multi-sig info
    function setMultiSigAddressesLink(string memory link) external onlyOwner {
        multiSigAddressesLink = link;

        emit MultiSignerAddressesUpdated(link);
    }

    /// @dev allows owner to add external link that contains token distribution plan
    function setTokenDistributionPlanLink(
        string memory link
    ) external onlyOwner {
        tokenDistributionPlanLink = link;

        emit TokenDistributionPlanUpdate(link);
    }

    /// @dev allows owner to add new signers
    function addSigner(address newSigner) external onlyOwner {
        require(newSigner != address(0), "MCT: Invalid signer address");
        require(!isSigner[newSigner], "MCT: Signer already exists");
        require(++signersCount <= 3, "MCT: Can Only Add 3 Signers");
        isSigner[newSigner] = true;
        emit NewSignerAdded(newSigner);
    }

    /// @dev allows signer to propose a remove signer operation
    function removeSigner(address signerToBeRemoved) external onlySigner {
        uint256 operationId = 8;
        require(
            !isOperationPending[operationId],
            "MCT: Operation already proposed"
        );

        isOperationPending[operationId] = true;
        operationTimestamp[operationId] = block.timestamp;
        operationApprovals[operationId] = 0;

        signerToRemove = signerToBeRemoved;
    }

    /// @dev allows signer to propose an operation
    function proposeOperation(uint256 operationId) external onlySigner {
        require(
            !isOperationPending[operationId],
            "MCT: Operation already proposed"
        );
        require(
            operationId > 0 && operationId <= 7,
            "MCT: Invalid opeation id"
        );
        isOperationPending[operationId] = true;
        operationTimestamp[operationId] = block.timestamp;
        operationApprovals[operationId] = 0;
    }

    /// @dev allows signer to propose an operation
    function cancelOperation(uint256 operationId) external onlyOwner {
        require(
            block.timestamp >
                operationTimestamp[operationId] + CANCELLATION_DELAY,
            "MCT: Operation out of time bound"
        );
        require(
            operationApprovals[operationId] < MINIMUM_REQUIRED_SIGNATURES,
            "MCT: Operation already approved"
        );
        require(isOperationPending[operationId], "MCT: Operation not proposed");

        delete isOperationPending[operationId];
        delete operationTimestamp[operationId];
        delete operationApprovals[operationId];
    }

    /// @dev allows signer to approve an operation
    function approveOperation(uint256 operationId) external onlySigner {
        require(isOperationPending[operationId], "MCT: Operation not proposed");
        require(
            operationApprovals[operationId] < MINIMUM_REQUIRED_SIGNATURES,
            "MCT: Operation already approved"
        );

        address[] memory prevSigners = operationApprovalSigner[operationId];

        for (uint256 i; i < prevSigners.length; i++) {
            require(prevSigners[i] != msg.sender, "MCT: Signer already signed");
        }

        operationApprovals[operationId]++;
        operationApprovalSigner[operationId].push(msg.sender);
    }

    /// @dev allows signer to execute an operation
    function executeOperation(
        uint256 operationId
    ) external onlySigner onlyAfterTimelock(operationId) {
        require(isOperationPending[operationId], "MCT: Operation not proposed");
        require(
            operationApprovals[operationId] >= MINIMUM_REQUIRED_SIGNATURES,
            "MCT: Not enough approvals for operation"
        );

        delete isOperationPending[operationId];
        delete operationTimestamp[operationId];
        delete operationApprovals[operationId];
        delete operationApprovalSigner[operationId];

        if (operationId == 1) {
            _claim(
                1,
                0,
                MINING_POOL_ALLOCATION,
                MINING_POOL_VESTING,
                MINING_POOL_RECEIVER
            );
        } else if (operationId == 2) {
            _claim(
                2,
                0,
                AIRDROP_ALLOCATION,
                AIRDROP_VESTING,
                AIRDROP_POOL_RECEIVER
            );
        } else if (operationId == 3) {
            _claim(
                3,
                RESERVE_POOL_LOCKUP,
                RESERVE_POOL_ALLOCATION,
                RESERVE_POOL_VESTING,
                RESERVE_POOL_RECEIVER
            );
        } else if (operationId == 4) {
            _claim(
                4,
                0,
                OPERATIONAL_POOL_ALLOCATION,
                OPERATIONAL_POOL_VESTING,
                OPERATIONAL_POOL_RECEIVER
            );
        } else if (operationId == 5) {
            _claim(
                5,
                TEAM_LOCKUP,
                TEAM_ALLOCATION,
                TEAM_VESTING,
                TEAM_RECEIVER
            );
        } else if (operationId == 6) {
            _claim(6, 0, INITIAL_SUPPLY_ALLOCATION, 1, INITIAL_SUPPLY_RECEIVER);
        } else if (operationId == 7) {
            _claim(7, 0, INVESTOR_ALLOCATION, 1, INVESTOR_POOL_RECEIVER);
        } else if (operationId == 8) {
            _removeSigner(signerToRemove);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL/HELPER METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev allows owner to remove existing signer
    function _removeSigner(address outgoingSigner) internal {
        require(isSigner[outgoingSigner], "MCT: Signer does not exist");
        require(
            --signersCount >= MINIMUM_REQUIRED_SIGNATURES,
            "MCT: Signers fall below required threshold"
        );

        /// @dev remove the current valid votes of voter.
        for (uint256 i = 1; i < 8; i++) {
            bool isVoter = _findVoter(
                operationApprovalSigner[i],
                outgoingSigner
            );

            if (isVoter) {
                operationApprovals[i]--;
            }
        }

        signerToRemove = address(0);
        isSigner[outgoingSigner] = false;
        emit OldSignerRemoved(outgoingSigner);
    }

    /// @dev parses and array and find if its available
    function _findVoter(
        address[] memory votersArray,
        address voter
    ) internal pure returns (bool) {
        for (uint256 j; j < votersArray.length; j++) {
            if (votersArray[j] == voter) {
                return true;
            }
        }

        return false;
    }

    /// @dev helps to resolve lock-in and vesting before minting tokens
    function _claim(
        uint256 poolId,
        uint256 lockIn,
        uint256 poolAllocation,
        uint256 vestingPeriod,
        address receiver
    ) internal {
        require(block.timestamp > START_TIME + lockIn, "MCT: Lock-in Period");
        uint256 totalReward;
        uint256 weeksElapsed;

        /// @dev pools with no vesting & lockup
        if (poolId == 6 || poolId == 7) {
            totalReward = poolAllocation;
        } else {
            /// @dev pools with lockup & vesting
            uint256 timeDiff;

            if (poolLastClaimTime[poolId] == 0) {
                timeDiff = block.timestamp - (START_TIME + lockIn);
            } else {
                timeDiff = block.timestamp - poolLastClaimTime[poolId];
            }

            weeksElapsed = timeDiff / 1 weeks;
            require(weeksElapsed > 0, "MCT: Claim Period Invalid");

            uint256 weeklyReward = poolAllocation / vestingPeriod;
            totalReward = weeksElapsed * weeklyReward;
        }

        if (totalReward > poolAllocation) {
            totalReward = poolAllocation - poolClaimedAmount[poolId];
        }

        require(
            poolClaimedAmount[poolId] + totalReward <= poolAllocation,
            "MCT: Claim Limit Reached"
        );

        poolClaimedAmount[poolId] += totalReward;

        if (poolLastClaimTime[poolId] == 0) {
            poolLastClaimTime[poolId] =
                START_TIME +
                lockIn +
                (weeksElapsed * 1 weeks);
        } else {
            poolLastClaimTime[poolId] += weeksElapsed * 1 weeks;
        }

        poolLastClaimTime[poolId] = block.timestamp;
        _mintNow(receiver, totalReward);
    }

    /// @dev helps mint more tokens to supply
    function _mintNow(address to_, uint256 amount_) internal {
        require(
            totalSupply() + amount_ <= MAX_SUPPLY,
            "MCT: Max Supply Reached"
        );
        _mint(to_, amount_);
    }

    /// @dev before token transfer hook to check investor wallet
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        /// @dev only one time a wallet can invest during vesting period
        if (from == INVESTOR_POOL_RECEIVER && to != from) {
            require(investment[to] == 0, "MCT: Existing Investor");
            investment[to] = amount;
            investedAt[to] = block.timestamp;
        }

        if (investment[from] > 0) {
            /// @dev passes lock-in
            require(
                block.timestamp > investedAt[from] + 26 weeks,
                "MCT: Lock-In Period"
            );

            uint256 timeDiff = block.timestamp - investedAt[from];
            uint256 weeksElapsed = timeDiff / 1 weeks;

            /// @dev post vesting
            if (weeksElapsed >= 52) {
                investment[from] = 0;
                investedAt[from] = 0;
                investedAmountTransferred[from] = 0;
            }

            /// @dev during vesting after lock-in
            if (weeksElapsed < 52) {
                uint256 weeklyVesting = investment[from] / 52;
                uint256 amountVested = weeksElapsed * weeklyVesting;

                investedAmountTransferred[from] += amount;
                require(
                    investedAmountTransferred[from] <= amountVested,
                    "MCT: Exceeds previously vested amount"
                );
            }
        }
    }
}