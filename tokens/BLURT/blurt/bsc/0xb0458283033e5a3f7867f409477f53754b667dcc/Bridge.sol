pragma solidity >=0.6.12;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./ReentrancyGuard.sol";
import "./BBlurtToken.sol";
contract Bridge is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    event BridgeFeeChanged(address indexed changer, uint256 newFee);
    event OracleAddressChanged(address indexed newOracle);
    event BridgeSwapAppeared(address indexed sender, uint256 bTokenAmount, string steemAddress);
    event BridgeTokenSent(address indexed receiver, uint256 amount);
    event FeeAddressChanged(address indexed newAddr);
    event SteemBalanceUpdated(uint256 newBalance);

    struct bridgeTransaction {
        address sender;
        string steemAddress;
        uint256 bTokenAmount;
        uint256 steemWillBeReceived;
        uint256 feePaid;
    }

    mapping(uint256 => bridgeTransaction) public transactions;
    uint256 public transactionCount = 0;
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    BBlurtToken private bridgeToken;
    bridgeTransaction[] public Transactions;
    uint256 public bridgeFeeBP = 100; 
    uint256 public maxBridgeFeeBP = 1000;
    uint256 public currentSteemBalance;
    address public oracleAddress;
    address public feeAddress;
    
    constructor (
        BBlurtToken bToken,
        address feeAddr,
        uint256 steemBalance
    ) public {
        bridgeToken = bToken;
        feeAddress = feeAddr;
        currentSteemBalance = steemBalance;
    }

    function setBridgeFee(uint256 newFee) public onlyOwner {
        require(newFee <= maxBridgeFeeBP, "New fee is higher than max fee.");
        bridgeFeeBP = newFee;
        emit BridgeFeeChanged(msg.sender, newFee);
    }

    function setFeeAddress(address newFeeAddress) public onlyOwner {
        require(newFeeAddress != address(0),"New fee address can't be address zero.");
        feeAddress = newFeeAddress;
        emit FeeAddressChanged(newFeeAddress);
    }

    function setOracleAddress(address newOracleAddress) public onlyOwner {
        require(newOracleAddress != address(0),"Oracle address can't be zero.");
        oracleAddress = newOracleAddress;
        emit OracleAddressChanged(newOracleAddress);
    }

    function bridgeSwap(string memory steemAddress, uint256 bTokenAmount) public nonReentrant {
        require(msg.sender != address(0),"Caller can't be address zero");
        uint256 allowance = bridgeToken.allowance(msg.sender, address(this));
        require(allowance >= bTokenAmount,"Token spend is not allowed.");
        uint256 fee = bTokenAmount.mul(bridgeFeeBP).div(10000);
        uint256 netValue = bTokenAmount.sub(fee);
        require(netValue <= currentSteemBalance, "Blurt Wallet has not enough tokens to bridge."); 
        bridgeToken.transferFrom(msg.sender, address(feeAddress), fee); 
        bridgeToken.transferFrom(msg.sender, address(this), netValue); 
        bridgeTransaction memory transaction = bridgeTransaction({
            sender : msg.sender,
            steemAddress : steemAddress,
            bTokenAmount : bTokenAmount,
            steemWillBeReceived : netValue,
            feePaid : fee
        }); // bu data oracledan okunmalı.
        Transactions.push(transaction);
        transactions[transactionCount] = transaction;
        transactionCount = transactionCount.add(1);
        bridgeToken.transfer( BURN_ADDRESS, netValue);
        currentSteemBalance = currentSteemBalance.sub(netValue); 
        emit BridgeSwapAppeared(msg.sender,bTokenAmount,steemAddress);
    }


    function sendbTokens(address receiver, uint256 amount, uint256 totalAmount) public onlyOracle {

        require(receiver != address(0),"Receiver can't be zero address.");
        bridgeToken.mint(address(this), amount); 
        currentSteemBalance = currentSteemBalance.add(totalAmount);
        bridgeToken.transfer(address(receiver), amount);
        emit BridgeTokenSent(receiver, amount);
    }

    function getbTokenAddress() public view returns(BBlurtToken) {
        // return olarak address(token) döndürülebilir.
        return bridgeToken;
    }

    function setSteemBalance(uint256 newBalance) public onlyOracle {
        currentSteemBalance = newBalance;
        emit SteemBalanceUpdated(newBalance);
    } 

    function getContractbTokenBalance() public view returns(uint256) {
        return bridgeToken.balanceOf(address(this));
    }
    
    function getSteemBalance() public view returns(uint256) {
        return currentSteemBalance;
    }

    function getTransactionbyIndex(uint256 index) public view returns(        
        address sender,
        string memory steemAddress,
        uint256 bTokenAmount,
        uint256 steemWillBeReceived,
        uint256 feePaid) {
        require(index <= transactionCount,"Transaction index is higher than latest index.");
        return (transactions[index].sender, transactions[index].steemAddress, transactions[index].bTokenAmount, transactions[index].steemWillBeReceived, transactions[index].feePaid);
    }

    modifier onlyOracle() {
        require(msg.sender == oracleAddress,"Only oracle can call this function.");
        _;
    }

}