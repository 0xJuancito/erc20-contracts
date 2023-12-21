// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Ownable} from "./oz/access/Ownable.sol";
import {IERC20, ERC20, ERC20Permit, ERC20Votes} from "./oz/token/ERC20/extensions/ERC20Votes.sol";
import {SafeERC20} from "./oz/token/ERC20/utils/SafeERC20.sol";
import {IERC165} from "./oz/utils/introspection/IERC165.sol";
import {Address} from "./oz/utils/Address.sol";

import {OFTV2} from "./lz/token/oft/v2/OFTV2.sol";

import {IBuyTaxReceiver} from "./interfaces/IBuyTaxReceiver.sol";
import {IAntiMevStrategy} from "./interfaces/IAntiMevStrategy.sol";

/**
 * @title BenCoinV2
 * @author Ben Coin Collective
 *
 * BenCoinV2 is an ERC20 token contract with additional features such as taxing, anti-MEV protection and transfer blacklisting.
 *
 * The contract is part of the Ben Coin ecosystem.
 * The owner of this contract has control over functions such as setting taxes, managing whitelists, enabling/disabling features &
 * provides a way to recover tokens accidentally sent to the contract. It is not an upgradeable proxy contract, but can however
 * update logic for the anti-MEV strategy and buy tax receiving.
 *
 * No extra tokens can be minted after deployment, but this is a LayerZero cross chain compatible token contract, and is permitted to burn
 * on the source chain and mint on another, but the overall token count does not change.
 */
contract BenCoinV2 is OFTV2, ERC20Votes {
  using SafeERC20 for IERC20;

  event SetTax(uint buyTax, uint sellTax, bool isTaxing);
  event SetBuyTaxReceiver(address buyTaxReceiver);
  event SetTaxableContract(address taxableContract, bool isTaxable);
  event SetTaxWhitelist(address whitelist, bool isWhitelisted);
  event SetIsAntiMEV(bool isAntiMEV);
  event SetIsTransferBlacklisting(bool isBlacklisting);
  event SetTransferBlacklist(address blacklist, bool isBlacklisted);

  error OnlyMigrator();
  error MigratorSetOnInvalidChain();
  error MaxTaxExceeded();
  error BothAddressesAreContracts();
  error TransferBlacklisted(address);
  error InvalidBuyTaxReceiver();
  error InvalidArrayLength();
  error AlreadyInitialized();

  address private buyTaxReceiver;
  uint16 private buyTax;
  uint16 private sellTax;
  bool private isTaxingEnabled;
  bool private isAntiMEV;
  bool private isBlacklisting;
  bool private isInitialized;
  uint8 private taxFlag = NOT_TAXING;
  mapping(address contractAddress => bool isTaxable) private taxableAddress;
  mapping(address whitelist => bool isWhitelisted) private taxWhitelist; // For certain addresses to be exempt from tax like exchanges

  mapping(address blacklist => bool isBlacklisted) private transferBlacklist;
  IAntiMevStrategy private antiMEVStrategy;

  uint256 private constant MAX_TAX = 10; // 10%
  // Using 1 & 2 instead of 0 to save gas when resetting
  uint8 private constant NOT_TAXING = 1;
  uint8 private constant TAXING = 2;
  uint256 private constant FEE_DENOMINATOR = 10000;
  uint8 private constant SHARED_DECIMALS = 8;

  /**
   * @notice BenCoinV2 contract constructor
   */
  constructor() OFTV2("BEN", "BEN", SHARED_DECIMALS) ERC20Permit("BEN") {}

  /**
   * @notice Initializes the contract
   * @param _lzEndpoint The endpoint for Layer Zero
   * @param _buyTaxReceiver The address to send the buy tax to
   * @param _antiMEVStrategy The anti-MEV strategy to use
   * @param _migrator The migrator contract address for benV1 to benV2 (only used on Ethereum)
   * @param _migratorMintSupply The migrator contract address for benV1 to benV2 (only used on Ethereum)
   * @param _buyTax The buy tax (10000 basis points, so 300 is 3%)
   * @param _sellTax The sell tax (10000 basis points, so 100 is 1%)
   * @param _isTaxingEnabled Whether or not taxing is enabled
   * @param _isAntiMEV Whether or not anti-MEV is enabled
   * @param _isTransferBlacklisting Whether or not transfer blacklisting is enabled
   */
  function initialize(
    address _lzEndpoint,
    address _buyTaxReceiver,
    address _antiMEVStrategy,
    address _migrator,
    uint256 _migratorMintSupply,
    uint256 _buyTax,
    uint256 _sellTax,
    bool _isTaxingEnabled,
    bool _isAntiMEV,
    bool _isTransferBlacklisting
  ) external notInitialized onlyOwner {
    __OFTV2_init(_lzEndpoint);

    _setTax(_buyTax, _sellTax, _isTaxingEnabled);
    _setIsAntiMEV(_isAntiMEV);
    _setIsTransferBlacklisting(_isTransferBlacklisting);
    if (_isTaxingEnabled) {
      _setBuyTaxReceiver(_buyTaxReceiver);
    }

    antiMEVStrategy = IAntiMevStrategy(_antiMEVStrategy);
    isInitialized = true;
    if (_migrator != address(0)) {
      if (
        block.chainid != 1 && // ethereum
        block.chainid != 1337 && // ganache
        block.chainid != 31337 // hardhat
      ) {
        // Migrator can only be set on ethereum as well as local development chain ids like hardhat.
        // This is because the migrator gets minted with the whole supply to distribute during the V1 to V2 migration.
        revert MigratorSetOnInvalidChain();
      }

      // If the migrator is set then mint the total supply of BenV2 tokens to it
      _mint(_migrator, _migratorMintSupply);
    }
  }

  /**
   * @dev Modifier to check if the contract has been initialized
   */
  modifier notInitialized() {
    if (isInitialized) {
      revert AlreadyInitialized();
    }
    _;
  }

  /**
   * @dev Anti-MEV modifier
   * @param _from The sender address
   * @param _to The receiver address
   * @param _amount The amount being transferred
   */
  modifier antiMEV(
    address _from,
    address _to,
    uint256 _amount
  ) {
    if (isAntiMEV) {
      antiMEVStrategy.onTransfer(_from, _to, _amount, taxFlag == TAXING);
    }
    _;
  }

  /**
   * @notice Burns BEN coin
   * @param _amount The amount to burn
   */
  function burn(uint256 _amount) external {
    _burn(_msgSender(), _amount);
  }

  /**
   * @notice Burns BEN coin from a specific address which has given the sender an allowance
   * @param _account The account to burn from
   * @param _amount The amount to burn
   */
  function burnFrom(address _account, uint256 _amount) external {
    _spendAllowance(_account, _msgSender(), _amount);
    _burn(_account, _amount);
  }

  function _mint(address _account, uint256 _amount) internal override(ERC20, ERC20Votes) {
    ERC20Votes._mint(_account, _amount);
  }

  function _burn(address _account, uint256 _amount) internal override(ERC20, ERC20Votes) {
    ERC20Votes._burn(_account, _amount);
  }

  function _beforeTokenTransfer(
    address _from,
    address _to,
    uint256 _amount
  ) internal override(ERC20) antiMEV(_from, _to, _amount) {
    if (isBlacklisting && transferBlacklist[_from]) {
      revert TransferBlacklisted(_from);
    }

    ERC20._beforeTokenTransfer(_from, _to, _amount);

    if (isTaxingEnabled && taxFlag == NOT_TAXING && taxableAddress[_to] && !taxWhitelist[_from]) {
      taxFlag = TAXING; // Set this so no further taxing is done by other transfers
      IBuyTaxReceiver(buyTaxReceiver).swapCallback();
      taxFlag = NOT_TAXING;
    }
  }

  function _afterTokenTransfer(address _from, address _to, uint256 _amount) internal override(ERC20, ERC20Votes) {
    ERC20Votes._afterTokenTransfer(_from, _to, _amount);

    // Take a fee if it is a taxable contract
    if (isTaxingEnabled && taxFlag == NOT_TAXING) {
      // If it's a buy then we take from who-ever it is sent to and send to the contract for selling back to ETH
      if (taxableAddress[_from] && !taxWhitelist[_to]) {
        uint256 fee = _calcTax(buyTax, _amount);
        // Transfers from the receiver to the buy tax receiver for later selling
        taxFlag = TAXING;
        _transfer(_to, buyTaxReceiver, fee);
        taxFlag = NOT_TAXING;
      } else if (taxableAddress[_to] && !taxWhitelist[_from]) {
        uint256 fee = _calcTax(sellTax, _amount);
        // Transfers from taxable contracts (like LPs) to the admin directly
        taxFlag = TAXING;
        _transfer(_to, owner(), fee);
        taxFlag = NOT_TAXING;
      }
    }
  }

  /**
   * @notice Calculate the tax fee
   * @param _tax The tax rate in basis points (10000 basis points = 100%)
   * @param _amount The amount to apply the tax to
   * @return fees The calculated tax fees
   * @dev Internal function used to calculate tax fees
   */
  function _calcTax(uint256 _tax, uint256 _amount) private pure returns (uint256 fees) {
    fees = (_amount * _tax) / FEE_DENOMINATOR;
  }

  function _setTax(uint256 _buyTax, uint256 _sellTax, bool _isTaxingEnabled) internal {
    // Cannot set tax higher than MAX_TAX (10%)
    if ((_buyTax * MAX_TAX > FEE_DENOMINATOR) || (_sellTax * MAX_TAX > FEE_DENOMINATOR)) {
      revert MaxTaxExceeded();
    }

    buyTax = uint16(_buyTax);
    sellTax = uint16(_sellTax);
    isTaxingEnabled = _isTaxingEnabled;

    emit SetTax(_buyTax, _sellTax, _isTaxingEnabled);
  }

  function _setIsAntiMEV(bool _isAntiMEV) private {
    isAntiMEV = _isAntiMEV;
    emit SetIsAntiMEV(_isAntiMEV);
  }

  function _setIsTransferBlacklisting(bool _isBlacklisting) private {
    isBlacklisting = _isBlacklisting;
    emit SetIsTransferBlacklisting(_isBlacklisting);
  }

  function _setBuyTaxReceiver(address _buyTaxReceiver) private {
    if (
      !Address.isContract(_buyTaxReceiver) ||
      !IERC165(_buyTaxReceiver).supportsInterface(type(IBuyTaxReceiver).interfaceId)
    ) {
      revert InvalidBuyTaxReceiver();
    }
    buyTaxReceiver = _buyTaxReceiver;
    emit SetBuyTaxReceiver(_buyTaxReceiver);
  }

  /**
   * @notice Set the tax parameters
   * @param _buyTax The buy tax rate in basis points (10000 basis points = 100%)
   * @param _sellTax The sell tax rate in basis points (10000 basis points = 100%)
   * @param _isTaxingEnabled Whether or not taxing is enabled
   * @dev Only callable by the owner
   */
  function setTax(uint256 _buyTax, uint256 _sellTax, bool _isTaxingEnabled) external onlyOwner {
    _setTax(_buyTax, _sellTax, _isTaxingEnabled);
  }

  /**
   * @notice Set whether or not a contract is taxable
   * @param _taxableContract The contract to set taxable state for
   * @param _isTaxable Whether or not the contract is taxable
   * @dev Only callable by the owner
   */
  function setTaxableContract(address _taxableContract, bool _isTaxable) external onlyOwner {
    taxableAddress[_taxableContract] = _isTaxable;
    emit SetTaxableContract(_taxableContract, _isTaxable);
  }

  /**
   * @notice Set whether or not an address is whitelisted for tax
   * @param _whitelist The address to set whitelist state for
   * @param _isWhitelisted Whether or not the address is whitelisted
   * @dev Only callable by the owner
   */
  function setTaxWhitelist(address _whitelist, bool _isWhitelisted) external onlyOwner {
    taxWhitelist[_whitelist] = _isWhitelisted;
    emit SetTaxWhitelist(_whitelist, _isWhitelisted);
  }

  /**
   * @notice Set whether an anti-MEV strategy is used
   * @param _isAntiMEV Whether or not anti-MEV is enabled
   * @dev Only callable by the owner
   */
  function setIsAntiMEV(bool _isAntiMEV) external onlyOwner {
    _setIsAntiMEV(_isAntiMEV);
  }

  /**
   * @notice Set the anti-MEV strategy
   * @param _antiMEVStrategy The anti-MEV strategy to use
   * @dev Only callable by the owner
   */
  function setAntiMevStrategy(IAntiMevStrategy _antiMEVStrategy) external onlyOwner {
    antiMEVStrategy = _antiMEVStrategy;
  }

  /**
   * @notice Set whether or not transfer blacklisting is enabled
   * @param _isBlacklisting Whether or not transfer blacklisting is enabled
   * @dev Only callable by the owner
   */
  function setIsTransferBlacklisting(bool _isBlacklisting) external onlyOwner {
    _setIsTransferBlacklisting(_isBlacklisting);
  }

  /**
   * @notice Recover tokens sent to this contract by accident
   * @param _token The token to recover
   * @param _amount The amount to recover
   * @dev Only callable by the owner
   */
  function recoverToken(IERC20 _token, uint _amount) external onlyOwner {
    _token.safeTransfer(owner(), _amount);
  }

  /**
   * @notice Set the buy tax receiver address
   * @param _buyTaxReceiver The address to send the buy tax to
   * @dev Only callable by the owner
   */
  function setBuyTaxReceiver(address _buyTaxReceiver) external onlyOwner {
    _setBuyTaxReceiver(_buyTaxReceiver);
  }

  /**
   * @notice Set whether or not an address is blacklisted from transferring
   * @param _blacklist The address to set blacklist state for
   * @param _isBlacklisted Whether or not the address is blacklisted
   * @dev Only callable by the owner
   */
  function setTransferBlacklist(address _blacklist, bool _isBlacklisted) external onlyOwner {
    transferBlacklist[_blacklist] = _isBlacklisted;
    emit SetTransferBlacklist(_blacklist, _isBlacklisted);
  }
}
