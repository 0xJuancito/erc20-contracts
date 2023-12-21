pragma solidity^0.5.13;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

contract TokenSwap {

    mapping (bytes32 => mapping (address => Swap)) public swaps;

    IERC20 public tokenBase;

    using SafeMath for uint256;

    struct Swap {
        address to;
        uint amount;
        uint releaseTime;
        bool confirmed;
        uint256 fee;
    }

    constructor(address tokenAddr_) public {
        require(
            tokenAddr_ != address(0),
            "Zero address"
        );

        tokenBase = IERC20(tokenAddr_);
    }

    event LockEvent(
        bytes32 indexed secretHash,
        address indexed from,
        address to,
        uint256 amount,
        uint releaseTime,
        bool confirmed,
        uint256 fee
    );
    event ConfirmEvent(bytes32 indexed secretHash, address indexed from);
    event RedeemEvent(bytes32 indexed secretHash, address indexed from, bytes32 secret);
    event RefundEvent(bytes32 indexed secretHash, address indexed from);

    modifier onlyToken() {
        require(
            msg.sender == address(tokenBase),
            "Unauthorized: sender is not the token contract"
        );
        _;
    }

    function ensureLockExists(bytes32 secretHash, address sender) internal {
        require(
            swaps[secretHash][sender].to != address(0),
            "Swap not initialized"
        );
    }

    function ensureTransferSuccess(bool transferResult) internal {
        require(
            transferResult,
            "Transfer was failed"
        );
    }

    function lockBody(
        address from,
        address to,
        uint256 amount,
        uint releaseTime,
        bytes32 secretHash,
        bool confirmed,
        uint256 fee
    )
        internal
    {
        require(
            swaps[secretHash][from].to == address(0),
            "Lock with this secretHash already exists"
        );

        require(
            block.timestamp + 10 minutes <= releaseTime,
            "Release time in the past"
        );

        swaps[secretHash][from] = Swap({
            to: to,
            amount: amount,
            releaseTime: releaseTime,
            confirmed: confirmed,
            fee: fee
        });

        bool transferResult = tokenBase.transferFrom(from, address(this), amount.add(fee));
        ensureTransferSuccess(transferResult);

        emit LockEvent(secretHash, from, to, amount, releaseTime, confirmed, fee);
    }

    function lock(
        address to,
        uint256 amount,
        uint releaseTime,
        bytes32 secretHash,
        bool confirmed,
        uint256 fee
    )
        public
    {
        lockBody(msg.sender, to, amount, releaseTime, secretHash, confirmed, fee);
    }

    function lockFrom(
        address from,
        address to,
        uint256 amount,
        uint releaseTime,
        bytes32 secretHash,
        bool confirmed,
        uint256 fee
    )
        public onlyToken
    {
        lockBody(from, to, amount, releaseTime, secretHash, confirmed, fee);
    }

    function confirmSwap(bytes32 secretHash) public {
        ensureLockExists(secretHash, msg.sender);

        require(
            !swaps[secretHash][msg.sender].confirmed,
            "Confirmed swap"
        );

        swaps[secretHash][msg.sender].confirmed = true;
        emit ConfirmEvent(secretHash, msg.sender);
    }

    function redeem(bytes32 secret, address lockSender) public {
        bytes32 secretHash = sha256(abi.encode(secret));

        ensureLockExists(secretHash, lockSender);

        Swap memory swap = swaps[secretHash][lockSender];

        require(
            swap.confirmed,
            "Unconfirmed swap"
        );


        delete swaps[secretHash][lockSender];

        bool transferResult = tokenBase.transfer(swap.to, swap.amount.add(swap.fee));
        ensureTransferSuccess(transferResult);

        emit RedeemEvent(secretHash, msg.sender, secret);
    }

    function claimRefund(bytes32 secretHash) public {
        ensureLockExists(secretHash, msg.sender);

        Swap memory swap = swaps[secretHash][msg.sender];

        require(
            block.timestamp >= swap.releaseTime,
            "Funds still locked"
        );


        delete swaps[secretHash][msg.sender];

        bool transferResult = tokenBase.transfer(swap.to, swap.fee);
        ensureTransferSuccess(transferResult);
        transferResult = tokenBase.transfer(msg.sender, swap.amount);
        ensureTransferSuccess(transferResult);

        emit RefundEvent(secretHash, msg.sender);
    }
}
