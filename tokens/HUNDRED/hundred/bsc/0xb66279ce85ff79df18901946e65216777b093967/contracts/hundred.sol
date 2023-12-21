// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IPancakeSwapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IPancakeSwapV2Router02 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

contract HUNDRED is ERC20, Ownable {

    uint256 private constant TOTAL_SUPPLY = 101_000_000_000 * 10**18;
    uint256 public constant lockPeriod = 100 hours;

    address public pancakeSwapPair;
    IPancakeSwapV2Router02 public pancakeSwapRouter;

    event RouterUpdated(address indexed oldRouter, address indexed newRouter, address indexed newPair);
    event ExcludedFromLockPeriod(address indexed account);
    event IncludedInTimeLock(address indexed account);
    event Blacklisted(address indexed account);
    event Unblacklisted(address indexed account);

    mapping(address => uint256) public timeStamps;
    mapping(address => bool) public excludedFromLockPeriod;
    mapping(address => bool) public pancakeSwapPairs;
    mapping(address => bool) public blacklisted;


    constructor(address _pancakeSwapRouterAddress) ERC20("HUNDRED", "HUNDRED") {
    _mint(msg.sender, TOTAL_SUPPLY);
    IPancakeSwapV2Router02 _pancakeSwapRouter = IPancakeSwapV2Router02(_pancakeSwapRouterAddress);
    pancakeSwapRouter = _pancakeSwapRouter;
    pancakeSwapPair = IPancakeSwapV2Factory(_pancakeSwapRouter.factory())
    .createPair(address(this), _pancakeSwapRouter.WETH());


    // Exclude owner/dev wallet and router from lock period 
    excludedFromLockPeriod[msg.sender] = true;
    excludedFromLockPeriod[address(pancakeSwapRouter)] = true;

    emit ExcludedFromLockPeriod(msg.sender);
    emit ExcludedFromLockPeriod(address(pancakeSwapRouter));
    } 
    

    function setNewRouter(address _newRouterAddress) external onlyOwner {
    require(_newRouterAddress != address(0), "New router address cannot be the zero address");
    IPancakeSwapV2Router02 _newRouter = IPancakeSwapV2Router02(_newRouterAddress);
    address _pair = IPancakeSwapV2Factory(_newRouter.factory()).createPair(address(this), _newRouter.WETH());
    require(_pair != address(0), "New pair not found");

    // Update the pancakeSwapRouter and pancakeSwapPair addresses
    pancakeSwapRouter = _newRouter;
    pancakeSwapPairs[_pair] = true;
}

    function excludeFromLockPeriod(address _address) external onlyOwner {
    excludedFromLockPeriod[_address] = true;
    }   

    function includeInTimeLock(address _address) external onlyOwner {
    excludedFromLockPeriod[_address] = false;
    }
    

    function transfer(address recipient, uint256 amount) public override returns (bool) {
    address sender = _msgSender();
    _transfer(sender, recipient, amount); 
    return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
    _transfer(sender, recipient, amount);
    uint256 currentAllowance = allowance(sender, _msgSender());
    require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
    _approve(sender, _msgSender(), currentAllowance - amount);
    return true;
    }
  

    function _transfer(address sender, address recipient, uint256 amount) internal override {
    require(!blacklisted[sender], "Sender is blacklisted");
    require(!blacklisted[recipient], "Recipient is blacklisted");

    require(amount > 0, "Transfer amount must be greater than zero");
    require(balanceOf(sender) >= amount, "Insufficient balance");

    // Check if sender is in the time lock period
    if (!excludedFromLockPeriod[sender] && sender != owner() && sender != address(pancakeSwapRouter)) {
        require(block.timestamp >= timeStamps[sender], "Time lock is still active");
    }

    // Check if recipient is in the time lock period
    if (!excludedFromLockPeriod[recipient] && recipient != owner() && recipient != address(pancakeSwapRouter)) {
        require(timeStamps[recipient] == 0 || block.timestamp >= timeStamps[recipient], "Recipient in time lock");
        timeStamps[recipient] = block.timestamp + lockPeriod;
    }

    super._transfer(sender, recipient, amount);
}

    function blacklistAddress(address _address) external onlyOwner {
    require(!blacklisted[_address], "Address is already blacklisted");
    blacklisted[_address] = true;
    emit Blacklisted(_address);
}

    function unblacklistAddress(address _address) external onlyOwner {
    require(blacklisted[_address], "Address is not blacklisted");
    blacklisted[_address] = false;
    emit Unblacklisted(_address);
}

}
