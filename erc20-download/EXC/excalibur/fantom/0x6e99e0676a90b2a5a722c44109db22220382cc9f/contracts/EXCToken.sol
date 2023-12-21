// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./abstracts/ERC20/ERC20BurnSupply.sol";
import "./interfaces/tokens/IEXCToken.sol";

contract EXCToken is Ownable, ERC20("Excalibur token", "EXC"), ERC20BurnSupply, IEXCToken {
  using SafeMath for uint256;

  mapping(address => bool) public excludedFromAutoBurn;

  address private _divTokenContractAddress;
  address private _masterContractAddress;
  address private _routerContractAddress;
  uint256 private _autoBurnRate; // 100 = 1%

  uint256 public constant MAX_AUTO_BURN = 200; // = 2%

  constructor(address initSupplyAddress, uint256 initSupplyAmount) {
    _mint(initSupplyAddress, initSupplyAmount);
  }

  /********************************************/
  /****************** EVENTS ******************/
  /********************************************/

  event AutoBurnRateUpdated(uint256 previousRate, uint256 newRate);
  event ExcludedFromAutoBurn(address account, bool isExcludedFromAutoBurn);
  event MasterContractAddressInitialized(address masterContractAddress);
  event DivTokenContractAddressInitialized(address divTokenContractAddress);
  event RouterContractAddressInitialized(address routerContractAddress);

  /***********************************************/
  /****************** MODIFIERS ******************/
  /***********************************************/

  /*
   * @dev Throws error if called by any account other than the master, divToken and router
   */
  modifier onlyMasterOrDivTokenOrRouter() {
    require(_isMaster() || _isDivToken() || _isRouter(), "EXCToken: caller is not the master or divToken or router");
    _;
  }

  /**************************************************/
  /****************** PUBLIC VIEWS ******************/
  /**************************************************/

  function divTokenContractAddress() external view override returns (address) {
    return _divTokenContractAddress;
  }

  function masterContractAddress() external view returns (address) {
    return _masterContractAddress;
  }

  function routerContractAddress() external view returns (address) {
    return _routerContractAddress;
  }

  function autoBurnRate() external view override returns (uint256) {
    return _autoBurnRate;
  }

  function isExcludedFromAutoBurn(address account) external view returns (bool) {
    return excludedFromAutoBurn[account];
  }

  /****************************************************/
  /****************** INTERNAL VIEWS ******************/
  /****************************************************/

  /**
   * @dev Returns true if the caller is the divToken contract
   */
  function _isDivToken() internal view returns (bool) {
    return msg.sender == _divTokenContractAddress;
  }

  /**
   * @dev Returns true if the caller is the master contract
   */
  function _isMaster() internal view returns (bool) {
    return msg.sender == _masterContractAddress;
  }

  /**
   * @dev Returns true if the caller is the router contract
   */
  function _isRouter() internal view returns (bool) {
    return msg.sender == _routerContractAddress;
  }

  /*****************************************************************/
  /****************** EXTERNAL OWNABLE FUNCTIONS  ******************/
  /*****************************************************************/

  /**
   * @dev Setup Master contract address
   *
   * Can only be initialized one time
   * Must only be called by the owner
   */
  function initializeMasterContractAddress(address master) external onlyOwner {
    require(_masterContractAddress == address(0), "EXCToken: master already initialized");
    require(master != address(0), "EXCToken: master initialized to zero address");
    _masterContractAddress = master;
    emit MasterContractAddressInitialized(master);
  }

  /**
   * @dev Setup DivToken contract address
   *
   * Can only be initialized one time
   * Must only be called by the owner
   */
  function initializeDivTokenContractAddress(address divToken) external override onlyOwner {
    require(_divTokenContractAddress == address(0), "EXCToken: divToken already initialized");
    require(divToken != address(0), "EXCToken: divToken initialized to zero address");
    _divTokenContractAddress = divToken;
    emit DivTokenContractAddressInitialized(divToken);
  }

  /**
   * @dev Setup Router contract address
   *
   * Can only be initialized one time
   * Must only be called by the owner
   */
  function initializeRouterContractAddress(address router) external onlyOwner {
    require(_routerContractAddress == address(0), "EXCToken: router already initialized");
    require(router != address(0), "EXCToken: router initialized to zero address");
    _routerContractAddress = router;
    emit RouterContractAddressInitialized(router);
  }

  /**
   * @dev Creates `amount` token to `account`
   *
   * Must only be called by the Master or divToken or router
   * See {ERC20-_mint}
   */
  function mint(address account, uint256 amount) external override onlyMasterOrDivTokenOrRouter returns (bool) {
    _mint(account, amount);
    return true;
  }

  /**
   * @dev Destroys `amount` tokens from the caller
   *
   * See {ERC20BurnSupply-_burn}
   */
  function burn(uint256 amount) external override {
    _burn(msg.sender, amount);
  }

  /**
   * @dev Updates _autoBurnRate
   *
   * Can only be updated to a lower value than 3 (3%)
   * Must only be called by the owner
   */
  function updateAutoBurnRate(uint256 rate) external onlyOwner {
    require(rate <= MAX_AUTO_BURN, "EXCToken: autoBurnRate mustn't exceed maximum");
    uint256 prevAutoBurnRate = _autoBurnRate;
    _autoBurnRate = rate;
    emit AutoBurnRateUpdated(prevAutoBurnRate, _autoBurnRate);
  }

  /**
   * @dev Updates account's exclusion from autoBurn status
   *
   * Can only be called by the owner
   */
  function updateExcludedFromAutoBurn(address account, bool isExcludedFromAutoBurn_) external onlyOwner {
    excludedFromAutoBurn[account] = isExcludedFromAutoBurn_;
    emit ExcludedFromAutoBurn(account, isExcludedFromAutoBurn_);
  }

  /********************************************************/
  /****************** INTERNAL FUNCTIONS ******************/
  /********************************************************/

  function _burn(address account, uint256 amount) internal override(ERC20, ERC20BurnSupply) {
    ERC20BurnSupply._burn(account, amount);
  }

  /**
   * @dev Overrides _transfer to add autoBurn on each transfer
   */
  function _transfer(
    address sender,
    address recipient,
    uint256 amount
  ) internal override {
    if (amount == 0 || _autoBurnRate == 0 || excludedFromAutoBurn[sender] || excludedFromAutoBurn[recipient]) {
      // amount 0, autoBurn disabled or sender/recipient excluded from autoBurn
      super._transfer(sender, recipient, amount);
      return;
    }

    uint256 burnAmount = (amount.mul(_autoBurnRate)).div(10000);
    uint256 sendAmount = amount.sub(burnAmount);
    assert(amount == sendAmount + burnAmount);

    _burn(sender, burnAmount);
    super._transfer(sender, recipient, sendAmount);
  }
}
