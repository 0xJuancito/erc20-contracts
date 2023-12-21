// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2ERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


/// @custom:security-contact silur@cryptall.co
contract MFPS is ERC20, ERC20Burnable, ERC20Snapshot, Ownable, Pausable, ERC20Permit, ReentrancyGuard {
  uint256 public buyFee = 0; // decimal 10000
  uint256 public sellFee = 0; // decimal 10000
  uint256 public lastSnapshotTime = 0;
  address public stakingAddress = address(0);
  mapping (address => bool) isDex;
  IUniswapV2Router02 router;
  address public pancakePair;

  mapping (address => bool) whitelist;

  constructor() ERC20("Meta FPS", "MFPS") ERC20Permit("MFPS") {
    _mint(msg.sender, 2674000000 * 10 ** decimals());
    lastSnapshotTime = block.timestamp;
    router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    pancakePair = IUniswapV2Factory(router.factory()).createPair(address(this), router.WETH());
    whitelist[address(this)] = true;
    whitelist[msg.sender] = true;
    //isDex[address(router)] = true;
    isDex[pancakePair] = true;
    _approve(address(this), address(router), 2**256-1);
    _pause();
  }

  function snapshot() public onlyOwner {
    _snapshot();
  }

  function pause() public onlyOwner {
    _pause();
  }

  function unpause() public onlyOwner {
    _unpause();
  }

  function _beforeTokenTransfer(address from, address to, uint256 amount)
  internal
  whenNotPaused
  override(ERC20, ERC20Snapshot)
  {
    // this doesn't cost as much gas as you think, only O(logn) in the number of snaps...
    if (block.timestamp - lastSnapshotTime >= 1 days) {
      _snapshot();
      lastSnapshotTime = block.timestamp;
    }

    super._beforeTokenTransfer(from, to, amount);
  }

  // overridden to apply fees
  bool public swapLock = false;
  function _transfer(address from, address to, uint256 amount)
  internal
  whenNotPaused
  override(ERC20)
  {
    if ((buyFee > 0 || sellFee > 0) && (!whitelist[from] && !whitelist[to]) && !swapLock) {
      swapLock=true;
      uint256 fee = 0;
      if (isDex[from]) {
        fee  = (amount * buyFee)/10000;
      } else if (isDex[to]) {
        fee  = (amount * sellFee)/10000;
      }
      uint256 taxedAmount = amount - fee;
      if (fee > 0) {
	      super._transfer(from, address(this), fee);
      }
      if (fee > 0 && isDex[to]) {
       swapTokensForWETH(balanceOf(address(this)));
      }
      super._transfer(from, to, taxedAmount);
    } else {
      super._transfer(from, to, amount);
    }
    swapLock = false;
  }

  function _afterTokenTransfer(address from, address to, uint256 amount)
  internal
  override(ERC20)
  {

    super._afterTokenTransfer(from, to, amount);
  }

  function _mint(address to, uint256 amount)
  internal
  override(ERC20)
  {
    super._mint(to, amount);
  }

  function _burn(address account, uint256 amount)
  internal
  override(ERC20)
  {
    super._burn(account, amount);
  }

  function getBalanceIntegral(address account, uint256 steps, uint256 decay) public view returns (uint256) {
    uint256 currentSnapshot = _getCurrentSnapshotId();
    require(currentSnapshot >= steps, "MFPS: Not enough snapshots");
    uint256 ret = 0;
    for (uint256 i=currentSnapshot-steps; i<=currentSnapshot; i++) {
      ret += balanceOfAt(account, i) * decay / 10000;
    }
    return ret;
  }

  function getVolumeIntegral(address account, uint256 steps, uint256 decay) public view returns (uint256) {
    uint256 currentSnapshot = _getCurrentSnapshotId();
    require(currentSnapshot > steps, "MFPS: Not enough snapshots");
    uint256 ret = 0;
    for (uint256 i = currentSnapshot-steps-1; i<=currentSnapshot; i++) {
      uint256 balanceBefore = balanceOfAt(account, i-1);
      uint256 balanceAfter = balanceOfAt(account, i);
      if (balanceBefore > balanceAfter) {
        ret += balanceBefore - balanceAfter;
      } else {
        ret += balanceAfter - balanceBefore;
      }
      ret *= decay / 10000;
    }
    return ret;
  }

  function setWhitelist(address addr, bool status) public onlyOwner {
    whitelist[addr] = status;
  }

  function setStakingAddress(address addr) public onlyOwner {
    require(stakingAddress == address(0) && addr != address(0));
    stakingAddress = addr;
  }

  event Mint(uint256 amount);
  function mintStakingRewards(uint256 amount) public nonReentrant {
    require(msg.sender == stakingAddress);
    _mint(stakingAddress, amount);
    emit Mint(amount);
  }

  function getBNBPrice() public view returns (uint256) {
    address[] memory path = new address[](2);
    path[0] = address(this);
    path[1] = router.WETH();
    uint256[] memory ret = router.getAmountsOut(1 * 10 ** decimals(), path);
    return ret[1];
  }

  function getUSDPrice() public view returns (uint256) {
    address[] memory path = new address[](3);
    path[0] = address(this);
    path[1] = router.WETH();
    path[2] = 0x55d398326f99059fF775485246999027B3197955; // BUSD
    uint256[] memory ret = router.getAmountsOut(1 * 10 ** decimals(), path);
    return ret[2];
  }

  function setFees(uint256 buy, uint256 sell) public onlyOwner {
    require(buy <= 1000 && sell <= 1000, "fees cannot exceed 10%");
    buyFee = buy;
    sellFee = sell;
  }


  function withdrawStuckTokens(address addr) external onlyOwner {
	  require(addr != address(this));
	  uint256 balance = IERC20(addr).balanceOf(address(this));
	  SafeERC20.safeTransfer(IERC20(addr), msg.sender, balance);
  }

  function swapTokensForWETH(uint256 tokenAmount) private {
    address[] memory path = new address[](2);
    path[0] = address(this);
    path[1] = router.WETH();
    router.swapExactTokensForTokens(
      tokenAmount,
      0, // accept any amount of ETH
      path,
      owner(),
      block.timestamp
    );
  }

  function setDex(address addr, bool val) external onlyOwner {
    isDex[addr] = val;
  }

  function isWhitelisted(address addr) external view returns (bool) {
    return whitelist[addr];
  }
}
