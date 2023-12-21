///SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

interface IBEP20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract AGROGLOBALTOKENV2 is IBEP20 {
    string public constant name = "Agro Global Token v2";
    string public constant symbol = "AGRO";
    uint8 public constant decimals = 18;
    uint256 public constant initialSupply = 95000000000;

    address private _owner;
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private blacklist;
    
    uint256 private _buyFee = 3; // Default buy fee
    uint256 private _sellFee = 5; // Default sell fee
    address private _feeAddress; // Fee Address
    address private _pairAddress; // DEX pair address
    bool private _feeEnabled = false; // Fee is disabled by default
    
    constructor() {
        _owner = msg.sender;
        _totalSupply = initialSupply * 10 ** decimals;
        _balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }
    
    modifier onlyOwner() {
        require(msg.sender == _owner, "Only the contract owner can call this function");
        _;
    }
    
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }
    
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }
    
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }
    
    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }
    
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender] - amount);
        return true;
    }

    function blacklist_address(address account) public onlyOwner {
        blacklist[account] = true;
    }

    function unblacklist_address(address account) public onlyOwner {
        blacklist[account] = false;
    }

    function setPairAddress(address pairAddress) public onlyOwner {
        _pairAddress = pairAddress;
    }
    
    function setBuyFee(uint256 buyFee) public onlyOwner {
        require(buyFee <= 100, "Buy fee percentage must be less than or equal to 100");
        _buyFee = buyFee;
    }
    
    function getBuyFee() public view returns (uint256) {
        return _buyFee;
    }
    
    function setSellFee(uint256 sellFee) public onlyOwner {
        require(sellFee <= 100, "Sell fee percentage must be less than or equal to 100");
        _sellFee = sellFee;
    }
    
    function getSellFee() public view returns (uint256) {
        return _sellFee;
    }
    
    function setFeeAddress(address feeAddress) public onlyOwner {
        _feeAddress = feeAddress;
    }
    
    function getFeeAddress() public view returns (address) {
        return _feeAddress;
    }
    
    function setFeeEnabled(bool feeEnabled) public onlyOwner {
        _feeEnabled = feeEnabled;
    }
    
    function isFeeEnabled() public view returns (bool) {
        return _feeEnabled;
    }
    
    function _transfer(address sender, address recipient, uint256 amount) private {
        require(sender != address(0), "Transfer from the zero address");
        require(recipient != address(0), "Transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(blacklist[sender] == false, "Sender is blacklisted");
        require(blacklist[recipient] == false, "Recipient is blacklisted");

        _balances[sender] = _balances[sender] - amount;

        //Buy
        if(_pairAddress == sender && _feeEnabled){
            uint256 feeAmount = amount * _buyFee / 100;
            _balances[recipient] = _balances[recipient] + amount - feeAmount;
            _balances[_feeAddress] = _balances[_feeAddress] + feeAmount;
        }
        //Sell
        else if(_pairAddress == recipient && _feeEnabled){
            uint256 feeAmount = amount * _sellFee / 100;
            _balances[recipient] = _balances[recipient] + amount - feeAmount;
            _balances[_feeAddress] = _balances[_feeAddress] + feeAmount;
        }
        //Normal transfer
        else{
            _balances[recipient] = _balances[recipient] + amount;
        }

        emit Transfer(sender, recipient, amount);
    }
    
    function _approve(address owner , address spender, uint256 amount) private {
        require(owner != address(0), "Approve from the zero address");
        require(spender != address(0), "Approve to the zero address");
        require(blacklist[owner] == false, "Sender is blacklisted");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}