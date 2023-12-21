// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IERC20
{
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract Ownable
{
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OwnershipRenounced();

    constructor()
    {
        address msgSender = _msgSender();
        owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function _msgSender() internal view virtual returns (address payable)
    {
        return payable(msg.sender);
    }

    function isOwner(address who) public view returns (bool)
    {
        return owner == who;
    }

    modifier onlyOwner()
    {
        require(isOwner(_msgSender()), "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address _newOwner) external virtual onlyOwner
    {
        require(_newOwner != owner, "Ownable: new owner is already the owner");
        owner = _newOwner;
        emit OwnershipTransferred(owner, _newOwner);
    }

    function renounceOwnership() external onlyOwner
    {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
        emit OwnershipRenounced();
    }

    function getTime() public view returns (uint256)
    {
        return block.timestamp;
    }
}

contract PartyToken is IERC20, Ownable
{
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    string  public name;
    string  public symbol;
    uint8   public decimals;
    uint256 public immutable totalSupply;

    error InsufficientBalance(uint256 available, uint256 required);
    error InsufficientAllowance(uint256 available, uint256 required);
    error ZeroAddressNotAllowed();
    error ZeroSupplyNotAllowed();
    error TransferAmountIsZero();

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _totalSupply
    ) payable
    {
        if (_totalSupply == 0) revert ZeroSupplyNotAllowed();

        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        totalSupply = _totalSupply;

        _balances[owner] = _totalSupply;
        emit Transfer(address(0), owner, _totalSupply);
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        if (amount > _allowances[sender][_msgSender()])
            revert InsufficientAllowance({
                available: _allowances[sender][_msgSender()],
                required: amount
            });

        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()] - amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) public virtual returns (bool) {
        if (subtractedValue <= _allowances[_msgSender()][spender])
            revert InsufficientAllowance({
                available: _allowances[_msgSender()][spender],
                required: subtractedValue
            });

        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] - subtractedValue);
        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        if (sender == address(0) || recipient == address(0))
            revert ZeroAddressNotAllowed();

        if (amount > _balances[sender])
            revert InsufficientBalance({
                available: _balances[sender],
                required: amount
            });

        if (amount == 0) revert TransferAmountIsZero();

        _balances[sender] -= amount;
        _balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        if (owner == address(0) || spender == address(0)) revert ZeroAddressNotAllowed();

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}