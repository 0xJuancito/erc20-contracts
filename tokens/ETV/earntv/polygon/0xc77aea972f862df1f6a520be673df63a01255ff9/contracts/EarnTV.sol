// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";

/// @title EarnTV
/// @notice ERC-20 implementation of EarnTV token
/// @author <iamdoraemon.eth> "0x63d596e6b6399bbb3cFA3075968946b870045955"
contract EarnTV is ERC20, Ownable2Step, Pausable {
    uint256 public constant FIXED_SUPPLY = 1_000_000_000 * 1 ether;
    mapping(address => bool) public isAdmin;
    uint256 public maxAccTransferLimit = 7500 * 1 ether; // 7500 ETV Tokens
    uint256 public timeBetweenSubmission = 21600 seconds; // 6 Hours
    uint256 internal lastSubmissionTimestamp;

    address public issuerContract;

    using SafeERC20 for IERC20;

    event LogBulkTransfer(
        address indexed from,
        address indexed to,
        uint256 amount,
        bytes32 activity
    );
    event LogAddAdmin(address admin, uint256 addedAt);
    event LogRemoveAdmin(address admin, uint256 removedAt);
    event MaxTransferLimitUpdated(uint256 oldLimit, uint256 newLimit);
    event TimeBetweenSubmissionUpdated(uint256 oldTime, uint256 newTime);
    event OwnershipTransferCancelled(address newOwner);
    event OwnershipTransferClaimed(address newOwner);
    event IssuerContractSet(address oldIssuer, address newIssuer);

    /**
     * @dev Modifier to make a function invocable by only the admin or owner account
     */
    modifier onlyAdminOrOwner() {
        //solhint-disable-next-line reason-string
        require(
            (isAdmin[msg.sender]) || (msg.sender == owner()),
            "Caller is neither admin nor owner"
        );
        _;
    }

    /**
     * @dev Modifier to make a function invocable by only the owenr or issuer contract
     */
    modifier onlyIssuerContract() {
        //solhint-disable-next-line reason-string
        require(msg.sender == issuerContract, "Caller is not issuer contract");
        _;
    }

    /**
     * @dev Sets the values for {name = EarnTV}, {totalSupply = 1,000,000,000}, {decimals = 18} and {symbol = ETV}.
     *
     * All of these values except admin are immutable: they can only be set once during
     * construction.
     */
    constructor(
        address contractOwner,
        address[] memory _admins
    ) ERC20("EarnTV", "ETV") {
        //solhint-disable-next-line reason-string
        require(
            contractOwner != address(0),
            "Contract owner can't be address zero"
        );
        uint256 adminLength = _admins.length;
        for (uint256 i = 0; i < adminLength; i++) {
            require(_admins[i] != address(0), "Admin can't be address zero");
            isAdmin[_admins[i]] = true;
            //solhint-disable-next-line not-rely-on-time
            emit LogAddAdmin(_admins[i], block.timestamp);
        }
        // Mint ETV tokens to contractOwner address
        super._mint(contractOwner, FIXED_SUPPLY); // Since Total supply is 1 Billion ETV
        // Transfers contract ownership to contractOwner
        super._transferOwnership(contractOwner);
    }

    /**
     * @dev To add a admin address in the contract
     *
     * Requirements:
     * - invocation can be done, only by the contract owner.
     */
    function addAdmin(address admin) external onlyOwner whenNotPaused {
        require(admin != address(0), "Admin can't be address zero");
        require(!isAdmin[admin], "Already an admin");
        isAdmin[admin] = true;
        //solhint-disable-next-line not-rely-on-time
        emit LogAddAdmin(admin, block.timestamp);
    }

    /**
     * @dev To remove a admin address from the contract
     *
     * Requirements:
     * - invocation can be done, only by the contract owner.
     */
    function removeAdmin(address admin) external onlyOwner whenNotPaused {
        require(admin != address(0), "Admin can't be address zero");
        require(isAdmin[admin], "Not an admin");
        isAdmin[admin] = false;
        //solhint-disable-next-line not-rely-on-time
        emit LogRemoveAdmin(admin, block.timestamp);
    }

    /**
     * @dev Destroys `amount` tokens from `msg.sender`, reducing the total supply.
     */
    function burn(uint256 amount) external whenNotPaused {
        _burn(msg.sender, amount);
    }

    /**
     * @dev Sets the issuer contract address
     */
    function setIssuerContract(
        address _issuerContract
    ) external onlyOwner whenNotPaused {
        require(_issuerContract != address(0), "Address zero");
        address oldIssuer = issuerContract;
        issuerContract = _issuerContract;
        emit IssuerContractSet(oldIssuer, _issuerContract);
    }

    /**
     * @dev Updates max account transfer limit
     */
    function updateMaxTransferLimit(
        uint256 _newLimit
    ) external onlyOwner whenNotPaused {
        // solhint-disable-next-line reason-string
        require(
            _newLimit <= 20000 * 1 ether,
            "Max acc transfer limit cannot be > 20K ETV"
        );
        uint256 oldLimit = maxAccTransferLimit;
        maxAccTransferLimit = _newLimit;
        emit MaxTransferLimitUpdated(oldLimit, _newLimit);
    }

    /**
     * @dev Updates time between submissions
     */
    function updateTimeBetweenSubmissions(
        uint256 timeInSeconds
    ) external onlyOwner whenNotPaused {
        // solhint-disable-next-line reason-string
        require(
            timeInSeconds <= 86400,
            "Time between submission cannot be > 1 Day"
        );
        uint256 oldTime = timeBetweenSubmission;
        timeBetweenSubmission = timeInSeconds * 1 seconds;
        emit TimeBetweenSubmissionUpdated(oldTime, timeBetweenSubmission);
    }

    /**
     * @dev Moves tokens `amount` from `tokenOwner` to `recipients`.
     */
    function bulkTransfer(
        address[] calldata recipients,
        uint256[] calldata amounts,
        bytes32[] calldata activities
    ) external onlyIssuerContract whenNotPaused {
        require(
            (recipients.length == amounts.length) &&
                (recipients.length == activities.length),
            "bulkTransfer: Unequal params"
        );
        require(
            // solhint-disable-next-line not-rely-on-time
            (block.timestamp - lastSubmissionTimestamp) >=
                timeBetweenSubmission,
            "Wait for next submission time"
        );
        lastSubmissionTimestamp = block.timestamp; // solhint-disable-line not-rely-on-time
        for (uint256 i = 0; i < recipients.length; i++) {
            require(
                amounts[i] <= maxAccTransferLimit,
                "Transfer limit crossed"
            );

            super.transferFrom(owner(), recipients[i], amounts[i]);

            emit LogBulkTransfer(
                msg.sender,
                recipients[i],
                amounts[i],
                activities[i]
            );
        }
    }

    /**
     * @dev To transfer stuck ERC20 tokens from within the contract
     *
     * Requirements:
     * - invocation can be done, only by the contract owner.
     */
    function withdrawStuckTokens(
        IERC20 token,
        address receiver
    ) external onlyOwner {
        require(address(token) != address(0), "Token cannot be address zero");
        uint256 amount = token.balanceOf(address(this));
        token.safeTransfer(receiver, amount);
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     * - invocation can be done, only by the contract owner & when the contract is not paused
     */
    function pause() external onlyAdminOrOwner whenNotPaused {
        _pause();
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     * - invocation can be done, only by the contract owner & when the contract is paused
     */
    function unpause() external onlyAdminOrOwner whenPaused {
        _unpause();
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(
        address recipient,
        uint256 amount
    ) public override whenNotPaused returns (bool) {
        return super.transfer(recipient, amount);
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override whenNotPaused returns (bool) {
        return super.transferFrom(sender, recipient, amount);
    }

    /**
     * @dev To view can submit transaction status
     */
    function canSubmitTransaction() external view returns (bool isSubmit) {
        return
            //solhint-disable-next-line not-rely-on-time
            (block.timestamp - lastSubmissionTimestamp) >=
            timeBetweenSubmission;
    }
}
