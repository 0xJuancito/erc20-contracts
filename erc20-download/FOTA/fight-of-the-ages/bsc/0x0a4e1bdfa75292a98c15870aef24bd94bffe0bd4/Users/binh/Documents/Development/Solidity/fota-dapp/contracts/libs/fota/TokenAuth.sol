// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";

contract TokenAuth is Context {

  address internal backup;
  address internal owner;
  mapping (address => bool) public gameAddresses;
  mapping (address => bool) public saleAddresses;
  mapping (address => uint) public advisorAddresses;
  mapping (address => uint) public founderAddresses;
  address marketingAddress;
  address liquidityPoolAddress;

  uint constant maxAdvisorAllocation = 35e24;
  uint constant maxFounderTeamAllocation = 70e24;
  uint advisorAllocated;
  uint founderAllocated;

  event OwnershipTransferred(address indexed _previousOwner, address indexed _newOwner);

  constructor(
    address _owner,
    address _liquidityPoolAddress
  ) {
    owner = _owner;
    backup = _owner;
    liquidityPoolAddress = _liquidityPoolAddress;
  }

  modifier onlyOwner() {
    require(isOwner(), "onlyOwner");
    _;
  }

  modifier onlyBackup() {
    require(isBackup(), "onlyBackup");
    _;
  }

  modifier onlyGameContract() {
    require(gameAddresses[_msgSender()], "TokenAuth: invalid caller");
    _;
  }

  modifier onlySaleContract() {
    require(saleAddresses[_msgSender()], "TokenAuth: invalid caller");
    _;
  }

  modifier onlyMarketingAddress() {
    require(_msgSender() == marketingAddress, "TokenAuth: invalid caller");
    _;
  }

  modifier onlyLiquidityPoolAddress() {
    require(_msgSender() == liquidityPoolAddress, "TokenAuth: invalid caller");
    _;
  }

  modifier onlyAdvisorAddress() {
    require(advisorAddresses[_msgSender()] > 0, "TokenAuth: invalid caller");
    _;
  }

  modifier onlyFounderAddress() {
    require(founderAddresses[_msgSender()] > 0, "TokenAuth: invalid caller");
    _;
  }

  function transferOwnership(address _newOwner) external onlyBackup {
    require(_newOwner != address(0), "TokenAuth: invalid new owner");
    owner = _newOwner;
    emit OwnershipTransferred(_msgSender(), _newOwner);
  }

  function updateBackup(address _newBackup) external onlyBackup {
    require(_newBackup != address(0), "TokenAuth: invalid new backup");
    backup = _newBackup;
  }

  function setGameAddress(address _gameAddress, bool _status) external onlyOwner {
    require(_gameAddress != address(0), "TokenAuth: game address is the zero address");
    gameAddresses[_gameAddress] = _status;
  }

  function setSaleAddress(address _address, bool _status) external onlyOwner {
    require(_address != address(0), "TokenAuth: sale address is the zero address");
    saleAddresses[_address] = _status;
  }

  function setMarketingAddress(address _address) external onlyOwner {
    require(_address != address(0), "TokenAuth: marketing address is the zero address");
    marketingAddress = _address;
  }

  function setLiquidityPoolAddress(address _address) external onlyOwner {
    require(_address != address(0), "TokenAuth: liquidity address is the zero address");
    liquidityPoolAddress = _address;
  }

  function setFounderAddress(address _address, uint _allocation) public virtual onlyOwner {
    require(_address != address(0), "TokenAuth: founder address is the zero address");
    require(founderAllocated + _allocation <= maxFounderTeamAllocation, "Invalid amount");
    founderAddresses[_address] = _allocation;
    founderAllocated = founderAllocated + _allocation;
  }

  function updateFounderAddress(address _oldAddress, address _newAddress) public virtual onlyOwner {
    require(_oldAddress != address(0), "TokenAuth: founder address is the zero address");
    founderAddresses[_newAddress] = founderAddresses[_oldAddress];
    delete founderAddresses[_oldAddress];
  }

  function setAdvisorAddress(address _address, uint _allocation) public virtual onlyOwner {
    require(_address != address(0), "TokenAuth: advisor address is the zero address");
    require(advisorAllocated + _allocation <= maxAdvisorAllocation, "Invalid amount");
    advisorAddresses[_address] = _allocation;
    advisorAllocated = advisorAllocated + _allocation;
  }

  function updateAdvisorAddress(address _oldAddress, address _newAddress) public virtual onlyOwner {
    require(_oldAddress != address(0), "TokenAuth: advisor address is the zero address");
    advisorAddresses[_newAddress] = advisorAddresses[_oldAddress];
    delete advisorAddresses[_oldAddress];
  }

  function isOwner() public view returns (bool) {
    return _msgSender() == owner;
  }

  function isBackup() public view returns (bool) {
    return _msgSender() == backup;
  }
}
