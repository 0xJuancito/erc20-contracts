// SPDX-License-Identifier: MIT


// ██╗░░░░░██╗░░░██╗███╗░░░███╗██╗███╗░░██╗░█████╗░
// ██║░░░░░██║░░░██║████╗░████║██║████╗░██║██╔══██╗
// ██║░░░░░██║░░░██║██╔████╔██║██║██╔██╗██║███████║
// ██║░░░░░██║░░░██║██║╚██╔╝██║██║██║╚████║██╔══██║
// ███████╗╚██████╔╝██║░╚═╝░██║██║██║░╚███║██║░░██║
// ╚══════╝░╚═════╝░╚═╝░░░░░╚═╝╚═╝╚═╝░░╚══╝╚═╝░░╚═╝

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract LuminaBot is ERC20, ERC20Burnable, Ownable {
  using SafeMath for uint256;
  using Address for address;

  bool public initialized = false;

  mapping(address => bool) private _isExcludedFromFee;

  address public luminaFeeWalletAddress;
  address public distFeeWalletAddress;
  address public burnWalletAddress;

  uint256 public fee;

  address public pairAddr;

  constructor(
    address _luminaFeeWalletAddress,
    address _distFeeWalletAddress,
    address _burnWalletAddress,
    address _router
  ) ERC20("Lumina Bot", "LBOT") {
    fee = 250;
    luminaFeeWalletAddress = _luminaFeeWalletAddress;
    distFeeWalletAddress = _distFeeWalletAddress;
    burnWalletAddress = _burnWalletAddress;

    _isExcludedFromFee[owner()] = true;
    _isExcludedFromFee[address(this)] = true;
    _isExcludedFromFee[luminaFeeWalletAddress] = true;
    _isExcludedFromFee[distFeeWalletAddress] = true;
    _isExcludedFromFee[burnWalletAddress] = true;
    _isExcludedFromFee[_router] = true;

    pairAddr = IUniswapV2Factory(IUniswapV2Router02(_router).factory()).createPair(address(this), IUniswapV2Router02(_router).WETH());

    uint256 totalTokens = 22000 ether;
    _mint(owner(), totalTokens); // for adding liquidity
  }

  function excludeFromFee(address account) public onlyOwner {
    require(!_isExcludedFromFee[account], "Account is already excluded");
    _isExcludedFromFee[account] = true;
  }

  function includeInFee(address account) public onlyOwner {
    require(_isExcludedFromFee[account], "Account is already included");
    _isExcludedFromFee[account] = false;
  }

  function setFeePercent(uint256 _fee) external onlyOwner {
    require(_fee >= 0, "Fee out of range");
    require(_fee <= 300, "Fee too high");
    fee = _fee;
  }

  function setLuminaFeeWalletAddress(address _addr) public onlyOwner {
    require(luminaFeeWalletAddress != _addr, "Address is already set!");
    _isExcludedFromFee[luminaFeeWalletAddress] = false;
    luminaFeeWalletAddress = _addr;
    _isExcludedFromFee[luminaFeeWalletAddress] = true;
  }

  function setDistFeeWalletAddress(address _addr) public onlyOwner {
    require(distFeeWalletAddress != _addr, "Address is already set!");
    _isExcludedFromFee[distFeeWalletAddress] = false;
    distFeeWalletAddress = _addr;
    _isExcludedFromFee[distFeeWalletAddress] = true;
  }

  function setBurnWalletAddress(address _addr) public onlyOwner {
    require(burnWalletAddress != _addr, "Address is already set!");
    _isExcludedFromFee[burnWalletAddress] = false;
    burnWalletAddress = _addr;
    _isExcludedFromFee[burnWalletAddress] = true;
  }

  function setPair(address _pair) public onlyOwner {
    require(_pair != address(0), "Zero address");
    pairAddr = _pair;
  }

  function isExcludedFromFee(address account) public view returns (bool) {
    return _isExcludedFromFee[account];
  }

  function _calculateAmountWithFees(uint256 amount) private view returns (uint256, uint256) {
    uint256 feeAmount = (amount * fee) / 10000;
    if (feeAmount == 0) return (amount, 0);
    return (amount - feeAmount, feeAmount);
  }

  function _tokenTransfer(
    address from,
    address to,
    uint256 amount
  ) private {
    if (!initialized && to != pairAddr) {
      revert("Not initialized!");
    }

    bool takeFee = true;
    if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
      takeFee = false;
    }

    if (to != pairAddr && from != pairAddr) {
      takeFee = false;
    }

    if (!takeFee || fee == 0) {
      _transfer(from, to, amount);
      return;
    }

    uint256 transferAmount;
    uint256 feeAmount;
    (transferAmount, feeAmount) = _calculateAmountWithFees(amount);
    _transfer(from, to, transferAmount);

    _transfer(from, luminaFeeWalletAddress, (feeAmount / 5) * 2);
    _transfer(from, distFeeWalletAddress, (feeAmount / 5) * 2);
    _transfer(from, burnWalletAddress, feeAmount / 5);
  }

  function transfer(address to, uint256 amount) public override returns (bool) {
    address from = _msgSender();
    _tokenTransfer(from, to, amount);
    return true;
  }

  function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
    address spender = _msgSender();
    _spendAllowance(from, spender, amount);
    _tokenTransfer(from, to, amount);
    return true;
  }

  function initialize() public onlyOwner {
    initialized = true;
  }
}
