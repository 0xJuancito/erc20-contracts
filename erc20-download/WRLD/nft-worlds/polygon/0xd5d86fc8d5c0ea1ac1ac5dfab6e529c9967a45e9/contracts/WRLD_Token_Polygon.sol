// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";

contract WRLD_Token_Polygon is ERC20, ERC20Capped, Ownable, ReentrancyGuard, ERC2771Context {
  uint public feeBps;
  uint public feeFixed;
  uint public feeCap;
  address private feeRecipient;
  address public childChainManagerProxy;

  event TransferRef(address indexed sender, address indexed recipient, uint256 amount, uint256 ref);

  /**
   * address _forwarder: The trusted forwarder contract address (WRLD_Forwarder_Polygon contract)
   * address _depositManager: The trusted polygon contract address for bridge deposits
   */

  constructor(address _forwarder, address _childChainManagerProxy)
  ERC20("NFT Worlds", "WRLD")
  ERC20Capped(5000000000 ether)
  ERC2771Context(_forwarder) {
    feeRecipient = _msgSender();
    childChainManagerProxy = _childChainManagerProxy;
  }

  function deposit(address user, bytes calldata depositData) external {
    require(_msgSender() == childChainManagerProxy, "Address not allowed to deposit.");

    uint256 amount = abi.decode(depositData, (uint256));

    _mint(user, amount);
  }

  function withdraw(uint256 amount) external {
    _burn(_msgSender(), amount);
  }

  function updateChildChainManager(address _childChainManagerProxy) external onlyOwner {
    require(_childChainManagerProxy != address(0), "Bad ChildChainManagerProxy address.");

    childChainManagerProxy = _childChainManagerProxy;
  }

  function setFees(uint _feeBps, uint _feeFixed, uint _feeCap) external onlyOwner {
    feeBps = _feeBps;
    feeFixed = _feeFixed;
    feeCap = _feeCap;
  }

  function setFeeRecipient(address recipient) external onlyOwner {
    require(recipient != address(0), "recipient is 0 addr");
    feeRecipient = recipient;
  }

  function transferWithFee(address recipient, uint256 amount) public nonReentrant returns (bool) {
    uint senderBalance = balanceOf(_msgSender());
    require(senderBalance >= amount, "ERC20: transfer amount exceeds balance.");

    uint percentageFee = amount * feeBps / 10000 + feeFixed;
    uint fee = percentageFee <= feeCap ? percentageFee : feeCap;

    _transfer(_msgSender(), feeRecipient, fee);
    _transfer(_msgSender(), recipient, amount - fee);

    return true;
  }

  function transferWithRef(address recipient, uint256 amount, uint256 ref) external returns (bool) {
    _transfer(_msgSender(), recipient, amount);
    emit TransferRef(_msgSender(), recipient, amount, ref);
    return true;
  }

  function transferWithFeeRef(address recipient, uint256 amount, uint256 ref) external returns (bool) {
    transferWithFee(recipient, amount);
    emit TransferRef(_msgSender(), recipient, amount, ref);
    return true;
  }

  /**
   * Overrides
   */

  function _msgSender() internal view override(Context, ERC2771Context) returns (address) {
    return super._msgSender();
  }

  function _msgData() internal view override(Context, ERC2771Context) returns (bytes calldata) {
    return super._msgData();
  }

  function _mint(address to, uint256 amount) internal override(ERC20, ERC20Capped) {
    super._mint(to, amount);
  }
}
