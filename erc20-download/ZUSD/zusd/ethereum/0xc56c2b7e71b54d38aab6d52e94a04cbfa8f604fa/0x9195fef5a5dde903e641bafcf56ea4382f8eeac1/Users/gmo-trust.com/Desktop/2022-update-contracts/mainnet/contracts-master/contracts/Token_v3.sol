pragma solidity 0.5.8;

import "./Token_v2.sol";
import "./Roles/Rescuer.sol";
import "./Roles/Operators.sol";
import { IERC20 } from "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";

contract Token_v3 is Token_v2, Rescuer, Operators {
    using SafeERC20 for IERC20;
    struct MintTransaction {
        address destination;
        uint amount;
        bool executed;
    }

    uint256 public mintTransactionCount;
    mapping (uint => mapping (address => bool)) public confirmations;
    mapping (uint => MintTransaction) public mintTransactions;

    modifier transactionExists(uint transactionId) {
        require (mintTransactions[transactionId].destination != address(0), "mint transaction does not exist.");
        _;
    }
    modifier notConfirmed(uint transactionId, address operator) {
        require (!confirmations[transactionId][operator], "mint transaction had been confirmed.");
        _;
    }

    event Rescue(IERC20 indexed tokenAddr, address indexed toAddr, uint256 amount);
    event RescuerChanged(address indexed oldRescuer, address indexed newRescuer, address indexed sender);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator, uint256 index, address indexed sender);
    event Confirmation(address indexed sender, uint indexed transactionId);
    event PendingMintTransaction(uint indexed transactionId, address indexed acount, uint amount, address indexed sender);

    // only admin can change rescuer
    function changeRescuer(address _account) public onlyAdmin whenNotPaused isNotZeroAddress(_account) {
        address old = rescuer;
        rescuer = _account;
        emit RescuerChanged(old, rescuer, msg.sender);
    }

    // rescue locked ERC20 Tokens
    function rescue(IERC20 _tokenContract, address _to, uint256 _amount) public whenNotPaused onlyRescuer {
        _tokenContract.safeTransfer(_to, _amount);
        emit Rescue(_tokenContract, _to, _amount);
    }

    // only admin can change operator
    function changeOperator(address _account, uint256 _index) public onlyAdmin whenNotPaused isNotZeroAddress(_account) {
        require(_index == 1 || _index == 2, "there is only two operators.");
        address old = operator1;
        if(_index == 1){
            operator1 = _account;
        }else{
            old = operator2;
            operator2 = _account;
        }
        emit OperatorChanged(old, _account, _index, msg.sender);
    }

    function addMintTransaction(address _account, uint _amount)
        internal
        returns (uint transactionId)
    {
        transactionId = mintTransactionCount;
        mintTransactions[transactionId] = MintTransaction({
            destination: _account,
            amount: _amount,
            executed: false
        });
        mintTransactionCount += 1;
        emit PendingMintTransaction(transactionId, _account, _amount, msg.sender);
    }

    function confirmMintTransaction(uint transactionId)
        public
        onlyOperator
        whenNotPaused
        transactionExists(transactionId)
        notConfirmed(transactionId, msg.sender)
    {
        confirmations[transactionId][msg.sender] = true;
        emit Confirmation(msg.sender, transactionId);
        executeTransaction(transactionId);
    }

    function mint(address _account, uint256 _amount) public onlyMinter whenNotPaused notMoreThanCapacity(totalSupply().add(_amount)) onlyNotProhibited(_account) isNaturalNumber(_amount){
        require(_account != address(0), "mint destination is the zero address");
        addMintTransaction(_account, _amount);
    }

    function executeTransaction(uint transactionId)
        internal
    {
        if (isConfirmed(transactionId)) {
            mintTransactions[transactionId].executed = true;

            _mint(mintTransactions[transactionId].destination, mintTransactions[transactionId].amount);
            emit Mint(mintTransactions[transactionId].destination, mintTransactions[transactionId].amount, msg.sender);
        }
    }

    function isConfirmed(uint transactionId)
        public
        view
        returns (bool)
    {
        if(confirmations[transactionId][operator1] &&
            confirmations[transactionId][operator2]){
                return true;
        }
        return false;
    }

    function initializeV3(address _rescuer, address _operator1, address _operator2) public isNotZeroAddress(_rescuer) isNotZeroAddress(_operator1) isNotZeroAddress(_operator2){
        initializeRescuer(_rescuer);
        initializeOperators(_operator1, _operator2);
    }

    function transfer(address _recipient, uint256 _amount) public whenNotPaused onlyNotProhibited(msg.sender) onlyNotProhibited(_recipient) isNaturalNumber(_amount) returns (bool) {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    function transferFrom(address _sender, address _recipient, uint256 _amount) public whenNotPaused onlyNotProhibited(_sender) onlyNotProhibited(_recipient) isNaturalNumber(_amount) returns (bool) {
        return super.transferFrom(_sender, _recipient, _amount);
    }

    function burn(uint256 _amount) public onlyNotProhibited(msg.sender) isNaturalNumber(_amount) {
        _burn(msg.sender, _amount);
        emit Burn(msg.sender, _amount, msg.sender);
    }
}