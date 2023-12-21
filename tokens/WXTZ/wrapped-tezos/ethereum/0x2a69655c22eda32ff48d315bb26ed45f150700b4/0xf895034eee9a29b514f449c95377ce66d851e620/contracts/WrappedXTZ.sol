pragma solidity 0.5.13;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";

import {Ownable} from "./Ownable.sol";
import {TokenSwap} from "./TokenSwap.sol";

contract WrappedXTZ is Initializable, Ownable, ERC20, ERC20Detailed {

  function initialize(
    address initialHolder,
    uint256 initialSupply,
    uint8 decimals
  )
    public
    initializer
  {
    ERC20Detailed.initialize("Wrapped XTZ", "wXTZ", decimals);
    Ownable.initialize(_msgSender());
    _mint(initialHolder, initialSupply);
  }

  function approveAndLock(
    address bridgeAddress,
    address to,
    uint256 amount,
    uint releaseTime,
    bytes32 secretHash,
    bool confirmed,
    uint256 fee
  )
    public
  {
    TokenSwap bridge = TokenSwap(bridgeAddress);
    _approve(msg.sender, bridgeAddress, amount + fee);
    bridge.lockFrom(msg.sender, to, amount, releaseTime, secretHash, confirmed, fee);
  }

  function transfer(address recipient, uint256 amount) public returns(bool) {
    return super.transfer(recipient, amount);
  }

  function transferFrom(address sender, address recipient, uint256 amount) public returns(bool) {
    return super.transferFrom(sender, recipient, amount);
  }

  function burn(uint256 amount) public onlyOwner {
    _burn(_msgSender(), amount);
  }

  function mint(address beneficiary, uint256 amount) public onlyOwner {
    _mint(beneficiary, amount);
  }
}
