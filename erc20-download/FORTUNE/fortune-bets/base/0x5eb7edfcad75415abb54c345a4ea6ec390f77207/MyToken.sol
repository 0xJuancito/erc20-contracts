// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUniswapV2Pair {
    function sync() external;
}

contract MyToken {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    address public communityFund;
    address public lpAddress;
    uint256 public communityFundTaxRate;
    uint256 public lpTaxRate;
    address public owner;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 initialSupply,
        address _communityFund,
        address _lpAddress,
        uint256 _communityFundTaxRate,
        uint256 _lpTaxRate
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        _totalSupply = initialSupply * 10**uint256(decimals);
        _balances[msg.sender] = _totalSupply;
        communityFund = _communityFund;
        lpAddress = _lpAddress;
        communityFundTaxRate = _communityFundTaxRate;
        lpTaxRate = _lpTaxRate;
        owner = msg.sender;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    function setCommunityFundTaxRate(uint256 newTaxRate) external onlyOwner {
        communityFundTaxRate = newTaxRate;
    }

    function setLpTaxRate(uint256 newTaxRate) external onlyOwner {
        lpTaxRate = newTaxRate;
    }

    function renounceOwnership() external onlyOwner {
        owner = address(0);
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) external returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address _owner, address spender) external view returns (uint256) {
        return _allowances[_owner][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool) {
        _transfer(sender, recipient, amount);
        uint256 currentAllowance = _allowances[sender][msg.sender];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, msg.sender, currentAllowance - amount);
        }
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(msg.sender, spender, currentAllowance - subtractedValue);
        }
        return true;
    }

    function setLpAddress(address _newLpAddress) external onlyOwner {
        require(_newLpAddress != address(0), "New LP address cannot be the zero address");
        lpAddress = _newLpAddress;
    }

    function syncLp() external onlyOwner {
        IUniswapV2Pair(lpAddress).sync();
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        uint256 communityFundTaxAmount = (amount * communityFundTaxRate) / 100;
        uint256 lpTaxAmount = (amount * lpTaxRate) / 100;
        uint256 transferAmount = amount - communityFundTaxAmount - lpTaxAmount;

        _balances[sender] -= amount;
        _balances[recipient] += transferAmount;
        _balances[communityFund] += communityFundTaxAmount;

        // Distribute tax to LP address
        _balances[lpAddress] += lpTaxAmount;

        emit Transfer(sender, recipient, transferAmount);
        emit Transfer(sender, communityFund, communityFundTaxAmount);
        emit Transfer(sender, lpAddress, lpTaxAmount);
    }

    function _approve(
        address _owner,
        address spender,
        uint256 amount
    ) internal {
        require(_owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[_owner][spender] = amount;
        emit Approval(_owner, spender, amount);
    }

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}