// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.9;

import {IERC20} from '../../../@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IStandardERC20} from '../../base/interfaces/IStandardERC20.sol';
import {
  IMintableBurnableERC20
} from '../../tokens/interfaces/IMintableBurnableERC20.sol';
import {ISynthereumFixedRateWrapper} from './interfaces/IFixedRateWrapper.sol';
import {ISynthereumFinder} from '../../core/interfaces/IFinder.sol';
import {SynthereumInterfaces} from '../../core/Constants.sol';
import {PreciseUnitMath} from '../../base/utils/PreciseUnitMath.sol';
import {
  ReentrancyGuard
} from '../../../@openzeppelin/contracts/security/ReentrancyGuard.sol';
import {ERC2771Context} from '../../common/ERC2771Context.sol';
import {
  AccessControlEnumerable,
  Context
} from '../../../@openzeppelin/contracts/access/AccessControlEnumerable.sol';

contract SynthereumFixedRateWrapper is
  ISynthereumFixedRateWrapper,
  ReentrancyGuard,
  ERC2771Context,
  AccessControlEnumerable
{
  using PreciseUnitMath for uint256;

  struct ConstructorParams {
    // Synthereum finder
    ISynthereumFinder finder;
    // Synthereum fixed rate version
    uint8 version;
    // ERC20 collateral token
    IStandardERC20 pegCollateralToken;
    // ERC20 synthetic token
    IMintableBurnableERC20 fixedRateToken;
    // The addresses of admin, maintainer
    Roles roles;
    // Conversion rate
    uint256 rate;
  }

  //----------------------------------------
  // Constants
  //----------------------------------------

  string public constant override typology = 'FIXED_RATE';

  bytes32 public constant MAINTAINER_ROLE = keccak256('Maintainer');

  // Precision for math operations
  uint256 public constant PRECISION = 1e18;

  // Current rate set for the wrapper
  uint256 private immutable rate;

  // The fixedRate synthetic token associated with the wrapper
  IMintableBurnableERC20 private immutable fixedRateToken;

  // The peg collateral token associated with the wrapper
  IStandardERC20 private immutable pegCollateralToken;

  // Version of the fixed rate wrapper
  uint8 private immutable fixedRateVersion;

  //----------------------------------------
  // Storage
  //----------------------------------------

  // Storage from interface
  ISynthereumFinder private finder;

  // Total amount of peg collateral tokens deposited
  uint256 private totalDeposited;

  // Total amount of synthetic tokens minted
  uint256 private totalSyntheticTokens;

  // When contract is paused minting is revoked
  bool private paused;

  //----------------------------------------
  // Modifiers
  //----------------------------------------

  modifier isActive() {
    require(!paused, 'Contract has been paused');
    _;
  }

  modifier onlyMaintainer() {
    require(
      hasRole(MAINTAINER_ROLE, _msgSender()),
      'Sender must be the maintainer'
    );
    _;
  }

  //----------------------------------------
  // Events
  //----------------------------------------

  event Wrap(uint256 amountTokens, address recipient);
  event Unwrap(uint256 amountCollateral, address recipient);
  event ContractPaused();
  event ContractResumed();

  //----------------------------------------
  // Constructor
  //----------------------------------------

  /**
   * @notice Constructs the fixed rate wrapper contract
   * @param _params The parameters passed from deployer to construct the fixed rate wrapper contract
   */
  constructor(ConstructorParams memory _params) nonReentrant {
    require(
      _params.pegCollateralToken.decimals() <= 18,
      'Collateral has more than 18 decimals'
    );

    require(
      _params.fixedRateToken.decimals() == 18,
      'FixedRate token has more or less than 18 decimals'
    );

    rate = _params.rate;
    pegCollateralToken = _params.pegCollateralToken;
    fixedRateToken = _params.fixedRateToken;
    fixedRateVersion = _params.version;
    finder = _params.finder;
    _setRoleAdmin(DEFAULT_ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
    _setRoleAdmin(MAINTAINER_ROLE, DEFAULT_ADMIN_ROLE);
    _setupRole(DEFAULT_ADMIN_ROLE, _params.roles.admin);
    _setupRole(MAINTAINER_ROLE, _params.roles.maintainer);
  }

  //----------------------------------------
  // External
  //----------------------------------------

  /**
   * @notice Receives an amount of peg collateral tokens and mints new synthetic tokens based on the rate
   * @param _collateral The amount of peg collateral tokens to be wrapped
   * @param _recipient Address of the recipient to receive the newly minted fixed rate synthetic tokens
   * @return amountTokens The amount of newly minted fixed rate synthetic tokens
   */
  function wrap(uint256 _collateral, address _recipient)
    external
    override
    nonReentrant
    isActive
    returns (uint256 amountTokens)
  {
    pegCollateralToken.transferFrom(_msgSender(), address(this), _collateral);
    amountTokens = (_collateral * (10**(18 - pegCollateralToken.decimals())))
      .mul(rate);
    totalDeposited = totalDeposited + _collateral;
    totalSyntheticTokens += amountTokens;
    fixedRateToken.mint(_recipient, amountTokens);
    emit Wrap(amountTokens, _recipient);
  }

  /**
   * @notice Burns an amount of fixed rate synthetic tokens and releases peg collateral tokens based on the conversion rate
   * @param _tokenAmount The amount of fixed rate synthetic tokens to be burned
   * @param _recipient Address of the recipient to receive the peg collateral tokens
   * @return amountCollateral The amount of peg collateral tokens received
   */
  function unwrap(uint256 _tokenAmount, address _recipient)
    external
    override
    nonReentrant
    returns (uint256 amountCollateral)
  {
    require(
      fixedRateToken.balanceOf(_msgSender()) >= _tokenAmount,
      'Not enought tokens to unwrap'
    );
    fixedRateToken.transferFrom(_msgSender(), address(this), _tokenAmount);
    amountCollateral = totalDeposited.mul(
      _tokenAmount.div(totalSyntheticTokens)
    );
    fixedRateToken.burn(_tokenAmount);
    totalDeposited = totalDeposited - amountCollateral;
    totalSyntheticTokens -= _tokenAmount;
    pegCollateralToken.transfer(_recipient, amountCollateral);
    emit Unwrap(amountCollateral, _recipient);
  }

  /** @notice Allows the maintainer to pause the contract in case of emergency
   * which blocks minting of new fixed rate synthetic tokens
   */
  function pauseContract() external override onlyMaintainer {
    paused = true;
    emit ContractPaused();
  }

  /** @notice Allows the maintainer to resume the contract functionalities
   * unblocking the minting of new fixed rate synthetic tokens
   */
  function resumeContract() external override onlyMaintainer {
    paused = false;
    emit ContractResumed();
  }

  /** @notice Checks the address of the peg collateral token registered in the wrapper
   * @return collateralCurrency The address of the peg collateral token registered
   */
  function collateralToken()
    external
    view
    override
    returns (IERC20 collateralCurrency)
  {
    collateralCurrency = pegCollateralToken;
  }

  /** @notice Checks the symbol of the fixed rate synthetic token registered in the wrapper
   * @return The symbol of the fixed rate synthetic token associated with the wrapper
   */
  function syntheticTokenSymbol()
    external
    view
    override
    returns (string memory)
  {
    return IStandardERC20(address(fixedRateToken)).symbol();
  }

  /** @notice Checks the address of the fixed rate synthetic token registered in the wrapper
   * @return The address of the fixed rate synthetic token associated with the wrapper
   */
  function syntheticToken() external view override returns (IERC20) {
    return fixedRateToken;
  }

  /** @notice Checks the version of the fixed rate wrapper contract
   * @return The version of the fixed rate wrapper contract
   */
  function version() external view override returns (uint8) {
    return fixedRateVersion;
  }

  /** @notice Checks the SynthereumFinder associated with the fixed rate wrapper contract
   * @return The address of the SynthereumFinder
   */
  function synthereumFinder()
    external
    view
    override
    returns (ISynthereumFinder)
  {
    return finder;
  }

  /** @notice Check the conversion rate between peg-collateral and fixed-rate synthetic token
   * @return Coversion rate
   */
  function conversionRate() external view override returns (uint256) {
    return rate;
  }

  /** @notice Amount of peg collateral stored in the contract
   * @return totalDeposited peg collateral deposited
   */
  function totalPegCollateral() external view override returns (uint256) {
    return totalDeposited;
  }

  /** @notice Amount of synthetic tokens minted through the contract
   * @return totalSyntheticTokens synthetic tokens minted
   */
  function totalSyntheticTokensMinted()
    external
    view
    override
    returns (uint256)
  {
    return totalSyntheticTokens;
  }

  /** @notice Check if wrap can be performed or not
   * @return True if minting is paused, otherwise false
   */
  function isPaused() external view override returns (bool) {
    return paused;
  }

  /**
   * @notice Check if an address is the trusted forwarder
   * @param  forwarder Address to check
   * @return True is the input address is the trusted forwarder, otherwise false
   */
  function isTrustedForwarder(address forwarder)
    public
    view
    override
    returns (bool)
  {
    try
      finder.getImplementationAddress(SynthereumInterfaces.TrustedForwarder)
    returns (address trustedForwarder) {
      if (forwarder == trustedForwarder) {
        return true;
      } else {
        return false;
      }
    } catch {
      return false;
    }
  }

  function _msgSender()
    internal
    view
    override(ERC2771Context, Context)
    returns (address sender)
  {
    return ERC2771Context._msgSender();
  }

  function _msgData()
    internal
    view
    override(ERC2771Context, Context)
    returns (bytes calldata)
  {
    return ERC2771Context._msgData();
  }
}
