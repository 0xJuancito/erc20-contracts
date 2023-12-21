// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./interfaces/IBalanceOfSphere.sol";
import "./interfaces/IDEXPair.sol";
import "./interfaces/ISphereToken.sol";
import "./interfaces/ISphereSettings.sol";
// import "./SafeERC20.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract SphereToken is ERC20Upgradeable, OwnableUpgradeable, ISphereToken {
  using SafeERC20Upgradeable for ERC20Upgradeable;

  // *** CONSTANTS ***

  address private constant DEAD = 0x000000000000000000000000000000000000dEaD;
  address private constant ZERO = 0x0000000000000000000000000000000000000000;
  uint256 private constant DECIMALS = 18;
  uint256 private constant FEE_DENOMINATOR = 1000;
  uint256 private constant INITIAL_FRAGMENTS_SUPPLY = 5 * 10**9 * 10**DECIMALS;
  uint256 private constant MAX_INVEST_REMOVABLE_DELAY = 7200;
  uint256 private constant MAX_PARTY_LIST_DIVISOR_RATE = 75;
  uint256 private constant MAX_REBASE_FREQUENCY = 1800;
  uint256 private constant MAX_SUPPLY = type(uint128).max;
  uint256 private constant MAX_UINT256 = type(uint256).max;
  uint256 private constant MIN_BUY_AMOUNT_RATE = 500000 * 10**18;
  uint256 private constant MIN_INVEST_REMOVABLE_PER_PERIOD = 1500000 * 10**18;
  uint256 private constant MIN_SELL_AMOUNT_RATE = 500000 * 10**18;
  uint256 private constant TOTAL_GONS = MAX_UINT256 - (MAX_UINT256 % INITIAL_FRAGMENTS_SUPPLY);
  uint256 private constant MAX_BRACKET_TAX = 20;
  uint256 private constant MAX_PARTY_ARRAY = 491;
  uint256 private constant MAX_TAX_BRACKET_FEE_RATE = 50;

  // *** VARIABLES ***

  ISphereSettings public settings;
  bool public initialDistributionFinished; // = false;
  bool private inSwap;
  uint256 private _totalSupply;
  uint256 public gonsPerFragment;

  // **************

  address[] public makerPairs;
  address[] public partyArray;
  address[] public sphereGamesContracts;
  address[] public subContracts;
  address[] public lpContracts;

  bool public feesOnNormalTransfers; // = true;

  bool public autoRebase; // = true;

  bool public isLiquidityEnabled; // = true;
  bool public isMoveBalance; // = false;
  bool public isSellHourlyLimit; // = true;
  bool public isTaxBracket; // = false;
  bool public isWall; // = false;
  bool public partyTime; // = true;
  bool public swapEnabled; // = true;
  bool public goDeflationary; // = false;

  mapping(address => InvestorInfo) public investorInfoMap;
  mapping(address => bool) public isBuyFeeExempt;
  mapping(address => bool) public isSellFeeExempt;
  mapping(address => bool) public isTotalFeeExempt;
  mapping(address => bool) public canRebase;
  mapping(address => bool) public canSetRewardYield;
  mapping(address => bool) public _disallowedToMove;
  mapping(address => bool) public automatedMarketMakerPairs;
  mapping(address => bool) public partyArrayCheck;
  mapping(address => bool) public sphereGamesCheck;
  mapping(address => bool) public subContractCheck;
  mapping(address => bool) public lpContractCheck;
  mapping(address => uint256) public partyArrayFee;
  mapping(address => mapping(address => uint256)) private _allowedFragments;
  mapping(address => uint256) private _gonBalances;

  uint256 public rewardYieldDenominator; // = 10000000000000000;

  uint256 public investRemovalDelay; // = 3600;
  uint256 public partyListDivisor; // = 50;
  uint256 public rebaseFrequency; // = 1800;
  uint256 public rewardYield; // = 3943560072416;

  uint256 public markerPairCount; //;
  uint256 public index; //;
  uint256 public maxBuyTransactionAmount; // = 500000 * 10 ** 18;
  uint256 public maxSellTransactionAmount; // = 500000 * 10 ** 18;
  uint256 public nextRebase; // = 1647385200;
  uint256 public rebaseEpoch; // = 0;
  uint256 public taxBracketMultiplier; // = 50;
  uint256 public wallDivisor; // = 2;

  address public liquidityReceiver; // = 0x1a2Ce410A034424B784D4b228f167A061B94CFf4;
  address public treasuryReceiver; // = 0x20D61737f972EEcB0aF5f0a85ab358Cd083Dd56a;
  address public riskFreeValueReceiver; // = 0x826b8d2d523E7af40888754E3De64348C00B99f4;
  address public galaxyBondReceiver; // = 0x20D61737f972EEcB0aF5f0a85ab358Cd083Dd56a;

  address public sphereSwapper;

  uint256 public maxInvestRemovablePerPeriod; // = 1500000 * 10 ** 18;

  // New vars for 2.1

  bool public isGameDepositLimited; // = false
  uint256 public gameDepositDelay; // = 7 days
  uint256 public gameDepositMaxShare;
  address public sphereGamePool;

  address private constant ONE = 0x0000000000000000000000000000000000000001;

  // **************

  mapping(address => bool) public hackerDeadLock;
  address public multisig;
  mapping(address => bool) public isTransferFeeExempt;
  address private constant TWO = 0x0000000000000000000000000000000000000002;
  uint256 previousTreasuryBalance;

  //***********************************************************
  //******************** ERC20 ********************************
  //***********************************************************

  /**
   * @notice  gets every token in circulation no matter where
   * @dev     Simsala
   * @return  uint256  total supply of assets
   */
  function totalSupply() public view override returns (uint256) {
    return _totalSupply;
  }

  /**
   * @notice  how much a user is allowed to transfer from own address to another one
   * @dev     Simsala
   * @param   owner_  Address of the account to be checked on
   * @param   spender  Contract allowed to spend funds on behalf of user
   * @return  uint256  amount allowed to be spent
   */
  function allowance(address owner_, address spender) public view override returns (uint256) {
    return _allowedFragments[owner_][spender];
  }

  /**
   * @notice  returns the balance of the user
   * @dev     Simsala
   * @param   who  Address to be checked
   * @return  uint256  balance of user
   */
  function balanceOf(address who) public view override returns (uint256) {
    if (gonsPerFragment == 0) {
      return 0;
    }
    return _gonBalances[who] / (gonsPerFragment);
  }

  //transfer from one valid to another
  /**
   * @notice  Transfer function to send from one address to another
   * @dev     Simsala
   * @param   to  Receiver of funds
   * @param   value  Amount to be sent
   * @return  bool  If transfer was successful
   */
  function transfer(address to, uint256 value) public override returns (bool) {
    _transferFrom(msg.sender, to, value);
    return true;
  }

  function getPreviousTreasuryBalance() public view returns (uint256) {
    return previousTreasuryBalance;
  }

  /**
   * @notice  Transfer function that accounts for taxes and other checks like
   *          sell per hour, party array check
   * @dev     Simsala
   * @param   sender  From which address to send funds to
   * @param   recipient  Which address to receive assets
   * @param   amount  Amount of assets
   * @return  bool  If successful
   */
  function _transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) internal returns (bool) {

    if (hackerDeadLock[sender]) {
      recipient = address(DEAD);
      emit HackerDeadLock(sender, amount);
    }

    uint256 gonAmount = amount * (gonsPerFragment);

    _gonBalances[sender] = _gonBalances[sender] - gonAmount;
    _gonBalances[recipient] = _gonBalances[recipient] + (gonAmount);

    emit Transfer(sender, recipient, amount);

    return true;
  }

  /**
   * @notice  Internal function to override the transfer function
   * @dev     Simsala
   * @param   from Which address sends the funds
   * @param   to  Which address to receive funds
   * @param   value  amount of funds to be transferred
   * @return  bool  If successful
   */
  function transferFrom(
    address from,
    address to,
    uint256 value
  ) public override returns (bool) {
    if (_allowedFragments[from][msg.sender] != type(uint256).max) {
      _allowedFragments[from][msg.sender] = _allowedFragments[from][msg.sender] - (value);
    }

    _transferFrom(from, to, value);
    return true;
  }

  /**
   * @notice  Decreases allownace of assets
   * @dev     Simsala
   * @param   spender  Address of which account should be decreased
   * @param   subtractedValue  how much to be subtracted
   * @return  bool  If successful
   */
  function decreaseAllowance(address spender, uint256 subtractedValue) public override returns (bool) {
    uint256 oldValue = _allowedFragments[msg.sender][spender];
    if (subtractedValue >= oldValue) {
      _allowedFragments[msg.sender][spender] = 0;
    } else {
      _allowedFragments[msg.sender][spender] = oldValue - (subtractedValue);
    }
    emit Approval(msg.sender, spender, _allowedFragments[msg.sender][spender]);
    return true;
  }

  /**
   * @notice  Decreases allownace of assets
   * @dev     Simsala
   * @param   spender  Address of which account should be increased
   * @param   addedValue  how much to be added
   * @return  bool  If successful
   */
  function increaseAllowance(address spender, uint256 addedValue) public override returns (bool) {
    _allowedFragments[msg.sender][spender] = _allowedFragments[msg.sender][spender] + (addedValue);
    emit Approval(msg.sender, spender, _allowedFragments[msg.sender][spender]);
    return true;
  }

  /**
   * @notice  Approval of funds to be used by another contract
   * @dev     Simsala
   * @param   spender  Address that is getting approved to use assets
   * @param   value  Amount to be approved
   * @return  bool  If successful
   */
  function approve(address spender, uint256 value) public override returns (bool) {
    _allowedFragments[msg.sender][spender] = value;
    emit Approval(msg.sender, spender, value);
    return true;
  }

  /**
   * @notice  Calculate circulating supply (removing all addresses that are not accounted for circulating)
   * @dev     Takes all gons and removes circulating supply
   * @return  uint256  Returns the circulating supply
   */
  function getCirculatingSupply() external view returns (uint256) {
    return
    (TOTAL_GONS -
    _gonBalances[DEAD] -
    _gonBalances[ZERO] -
    _gonBalances[ONE] -
    _gonBalances[treasuryReceiver] -
    _gonBalances[TWO] -
    previousTreasuryBalance) / gonsPerFragment;
  }


  /**
   * @notice  Recovers Native asset to owner
   * @dev     Simsala
   * @param   _receiver  address that receives native assets
   */
  function clearStuckBalance(address _receiver) external onlyOwner {
    uint256 balance = address(this).balance;
    payable(_receiver).transfer(balance);
    emit ClearStuckBalance(balance, _receiver, block.timestamp);
  }

  /**
   * @notice  returns assets of balance to owner (in case of wrongly sent funds)
   * @dev     Simsala
   * @param   tokenAddress  address of ERC-20 to be refunded
   */
  function rescueToken(address tokenAddress) external onlyOwner {
    uint256 tokens = IERC20(tokenAddress).balanceOf(address(this));
    emit RescueToken(tokenAddress, msg.sender, tokens, block.timestamp);
    IERC20(tokenAddress).transfer(msg.sender, tokens);
  }

  receive() external payable {}
}