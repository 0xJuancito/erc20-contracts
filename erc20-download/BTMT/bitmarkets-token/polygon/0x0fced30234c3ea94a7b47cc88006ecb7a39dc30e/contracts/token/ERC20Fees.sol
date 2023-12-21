// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.14;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @custom:security-contact security@bitmarkets.com
abstract contract ERC20Fees is ERC20, ERC20Burnable {
  using SafeERC20 for IERC20;

  uint16 private _companyR;
  uint16 private _fundR;
  uint16 private _burnR;

  uint256 private _minimalSupply;

  address private _companyWallet;
  address private _companyRewardsWallet;
  address private _esgFundWallet;

  address private _feelessAdminWallet;
  mapping(address => bool) private _feeless;
  mapping(address => bool) private _feelessAdmins;

  mapping(address => uint256) private _fromCompanyRewards;
  mapping(address => uint256) private _fromESG;
  mapping(address => uint256) private _fromBurn;

  event FeelessAdminAdded(address indexed account);
  event FeelessAdded(address indexed account);
  event FeelessRemoved(address indexed account);

  /**
   * @dev Throws if called by any account that is not the feeless admin
   */
  modifier onlyFeelessAdmin() {
    require(_feelessAdminWallet == _msgSender(), "Caller not feeless admin");
    _;
  }

  /**
   * @dev Throws if called by any account that is not a feeless admin
   */
  modifier onlyFeelessAdmins() {
    require(_feelessAdmins[_msgSender()], "Caller not in feeless admins");
    _;
  }

  /**
   * @dev Constructor
   * @param finalSupply The minimum amount of token supply without the decimals
   * @param companyRate The percentage of every transfer to the company wallet (0-1000)
   * @param esgFundRate The percentage of every transfer that ends up in the ESG fund (0-1000)
   * @param burnRate The percentage of every transfer that gets burned until final supply is reached (0-1000)
   * @param companyWallet The company wallet address that gets tokens burned
   * @param companyRewardsWallet The company wallet address that receives transfer fees
   * @param esgFundWallet Fund wallet address that gathers transfer fees
   * @param feelessAdminWallet Feeless admin wallet address
   */
  constructor(
    uint32 finalSupply,
    uint16 companyRate,
    uint16 esgFundRate,
    uint16 burnRate,
    address companyWallet,
    address companyRewardsWallet,
    address esgFundWallet,
    address feelessAdminWallet
  ) {
    require(companyRate >= 0 && companyRate < 1000, "Company rate out of bounds");
    require(esgFundRate >= 0 && esgFundRate < 1000, "ESG Fund rate out of bounds");
    require(burnRate >= 0 && burnRate < 1000, "Burn rate out of bounds");
    require(companyRate + esgFundRate + burnRate <= 1000, "Rates add to > 1000");
    require(companyRewardsWallet != address(0), "Invalid rewards wallet");
    require(esgFundWallet != address(0), "Invalid esg fund wallet");
    require(feelessAdminWallet != address(0), "Invalid admin wallet");

    _minimalSupply = finalSupply * 10 ** decimals();

    _companyR = companyRate;
    _fundR = esgFundRate;
    _burnR = burnRate;

    _companyWallet = companyWallet;
    _companyRewardsWallet = companyRewardsWallet;
    _esgFundWallet = esgFundWallet;

    _feelessAdminWallet = feelessAdminWallet;
    _feelessAdmins[feelessAdminWallet] = true;

    _feeless[_companyRewardsWallet] = true;
    _feeless[_esgFundWallet] = true;
  }

  function addFeelessAdmin(address contractAddress) public virtual onlyFeelessAdmin {
    require(contractAddress != address(0), "Invalid address");
    require(!_feelessAdmins[contractAddress], "Already feeless admin");

    _feelessAdmins[contractAddress] = true;

    emit FeelessAdminAdded(contractAddress);
  }

  function addFeeless(address account) public virtual onlyFeelessAdmins {
    require(account != address(0), "Account is zero");
    require(!_feeless[account], "Account already feeless");

    _feeless[account] = true;

    emit FeelessAdded(account);
  }

  function removeFeeless(address account) public virtual onlyFeelessAdmins {
    require(account != address(0), "Account is zero");

    _feeless[account] = false;

    emit FeelessRemoved(account);
  }

  function isFeeless(address account) public view returns (bool) {
    return _feeless[account];
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal virtual override {
    super._beforeTokenTransfer(from, to, amount);

    if (
      from != address(0) && // Fees not on minting
      to != address(0) && // Nor on burning
      !isFeeless(from) && // To not go through this condition many times.
      !isFeeless(to) && // same
      amount > 0 &&
      balanceOf(from) >= amount
    ) {
      uint256 companyFee = (amount * _companyR) / 1000;
      uint256 fundFee = (amount * _fundR) / 1000;
      uint256 burnFee = (amount * _burnR) / 1000;

      _fromCompanyRewards[from] += companyFee;
      _fromESG[from] += fundFee;

      if (totalSupply() - burnFee > _minimalSupply) {
        _fromBurn[from] += burnFee;
      }
    }
  }

  function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual override {
    super._afterTokenTransfer(from, to, amount);

    if (
      from != address(0) && // Fees not on minting
      to != address(0) && // Nor on burning
      !isFeeless(from) && // To not go through this condition many times.
      !isFeeless(to) && // same
      amount > 0
    ) {
      uint256 companyFee = _fromCompanyRewards[from];
      uint256 fundFee = _fromESG[from];
      uint256 burnFee = _fromBurn[from];

      require(balanceOf(from) >= companyFee + fundFee + burnFee, "Not enough to pay");

      if (burnFee > 0 && totalSupply() - burnFee > _minimalSupply) {
        burn(burnFee);
        _fromBurn[from] = 0;
      }

      if (companyFee > 0) {
        transfer(_companyRewardsWallet, companyFee);
        _fromCompanyRewards[from] = 0;
      }

      if (fundFee > 0) {
        transfer(_esgFundWallet, fundFee);
        _fromESG[from] = 0;
      }
    }
  }
}
