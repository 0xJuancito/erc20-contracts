// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IUniswapV2Router01 {
  function factory() external pure returns (address);

  function WETH() external pure returns (address);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
  function swapExactTokensForETHSupportingFeeOnTransferTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external;
}

interface IUniswapV2Factory {
  function getPair(address tokenA, address tokenB) external view returns (address pair);

  function createPair(address tokenA, address tokenB) external returns (address pair);
}

contract OREO is ERC20Burnable, Ownable {
  using SafeMath for uint256;

  mapping(address => bool) public isExcludedFromFee;
  mapping(address => bool) public isMinter;
  mapping(address => bool) public whiteListedPair;

  uint256 public immutable MAX_SUPPLY;
  uint256 public BUY_FEE = 0;
  uint256 public SELL_FEE = 450;
  uint256 public TREASURY_FEE = 50;

  bool public autoSwap = true;

  uint256 public totalBurned = 0;

  address payable public devAddress;
  IUniswapV2Router02 public uniswapV2Router;

  event TokenRecoverd(address indexed _user, uint256 _amount);
  event FeeUpdated(address indexed _user, uint256 _feeType, uint256 _fee);
  event ToggleV2Pair(address indexed _user, address indexed _pair, bool _flag);
  event AddressExcluded(address indexed _user, address indexed _account, bool _flag);
  event MinterRoleAssigned(address indexed _user, address indexed _account);
  event MinterRoleRevoked(address indexed _user, address indexed _account);
  event UpdateUniswapV2Router(address indexed newAddress, address indexed oldAddress);

  constructor(
    uint256 _maxSupply,
    uint256 _initialSupply,
    address router_,
    address payable _dev
  ) public ERC20("OreoSwap", "OREO") {
    require(_initialSupply <= _maxSupply, "OREO: The _initialSupply should not exceed the _maxSupply");

    MAX_SUPPLY = _maxSupply;
    isExcludedFromFee[owner()] = true;
    isExcludedFromFee[address(this)] = true;
    isExcludedFromFee[devAddress] = true;
    devAddress = _dev;

    if (_initialSupply > 0) {
      _mint(_msgSender(), _initialSupply);
    }

    IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(router_);

    // address uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
    //   .createPair(address(this), _uniswapV2Router.WETH());

    // whiteListedPair[uniswapV2Pair] = true;

    // emit ToggleV2Pair(_msgSender(), uniswapV2Pair, true);

    uniswapV2Router = _uniswapV2Router;
  }

  modifier onlyDev() {
    require(devAddress == _msgSender() || owner() == _msgSender(), "OREO: You don't have the permission!");
    _;
  }

  modifier hasMinterRole() {
    require(isMinter[_msgSender()], "OREO: You don't have the permission!");
    _;
  }

  /************************************************************************/

  // function setAutoSwap(bool _flag) external onlyDev {
  //   autoSwap = _flag;
  // }

  // /************************************************************************/

  // function swapTokensForEth(uint256 tokenAmount) internal {
  //   // generate the uniswap pair path of token -> weth
  //   address[] memory path = new address[](2);
  //   path[0] = address(this);
  //   path[1] = uniswapV2Router.WETH();

  //   _approve(address(this), address(uniswapV2Router), tokenAmount);
  //   // make the swap
  //   uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
  //     tokenAmount,
  //     0, // accept any amount of ETH
  //     path,
  //     devAddress,
  //     block.timestamp
  //   );
  // }

  /************************************************************************/

  function _burn(address account, uint256 amount) internal override {
    super._burn(account, amount);
    totalBurned = totalBurned.add(amount);
  }

  /************************************************************************/

  function _transfer(
    address sender,
    address recipient,
    uint256 amount
  ) internal override {
    require(sender != address(0), "ERC20: transfer from the zero address");
    require(recipient != address(0), "ERC20: transfer to the zero address");

    uint256 burnFee;
    uint256 treasuryFee;

    if (whiteListedPair[sender]) {
      burnFee = BUY_FEE;
    } else if (whiteListedPair[recipient]) {
      burnFee = SELL_FEE;
      treasuryFee = TREASURY_FEE;
    }

    if (
      (isExcludedFromFee[sender] || isExcludedFromFee[recipient]) ||
      (!whiteListedPair[sender] && !whiteListedPair[recipient])
    ) {
      burnFee = 0;
      treasuryFee = 0;
    }

    uint256 burnFeeAmount = amount.mul(burnFee).div(10000);
    uint256 treasuryFeeAmount = amount.mul(treasuryFee).div(10000);

    if (burnFeeAmount > 0) {
      _burn(sender, burnFeeAmount);
      amount = amount.sub(burnFeeAmount);
      // amount = amount - burnFeeAmount;
    }

    if (treasuryFeeAmount > 0) {
      super._transfer(sender, devAddress, treasuryFeeAmount);

      amount = amount.sub(treasuryFeeAmount);
      // amount = amount - treasuryFeeAmount;
    }

    super._transfer(sender, recipient, amount);
  }

  /************************************************************************/

  function updateUniswapV2Router(address newAddress) public onlyDev {
    require(newAddress != address(uniswapV2Router), "OREO: The router already has that address");
    emit UpdateUniswapV2Router(newAddress, address(uniswapV2Router));
    uniswapV2Router = IUniswapV2Router02(newAddress);
    // address _uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory())
    //   .createPair(address(this), uniswapV2Router.WETH());
  }

  /************************************************************************/

  function mint(address _user, uint256 _amount) external hasMinterRole {
    uint256 _totalSupply = totalSupply();
    require(_totalSupply.add(_amount) <= MAX_SUPPLY, "OREO: No more minting allowed!");

    _mint(_user, _amount);
  }

  /**************************************************************************/

  function assignMinterRole(address _account) public onlyOwner {
    isMinter[_account] = true;

    emit MinterRoleAssigned(_msgSender(), _account);
  }

  function revokeMinterRole(address _account) public onlyOwner {
    isMinter[_account] = false;

    emit MinterRoleRevoked(_msgSender(), _account);
  }

  function excludeMultipleAccountsFromFees(address[] calldata _accounts, bool _excluded) external onlyDev {
    for (uint256 i = 0; i < _accounts.length; i++) {
      isExcludedFromFee[_accounts[i]] = _excluded;

      emit AddressExcluded(_msgSender(), _accounts[i], _excluded);
    }
  }

  function enableV2PairFee(address _account, bool _flag) external onlyDev {
    whiteListedPair[_account] = _flag;

    emit ToggleV2Pair(_msgSender(), _account, _flag);
  }

  function updateDevAddress(address payable _dev) external onlyDev {
    isExcludedFromFee[devAddress] = false;
    emit AddressExcluded(_msgSender(), devAddress, false);

    devAddress = _dev;
    isExcludedFromFee[devAddress] = true;

    emit AddressExcluded(_msgSender(), devAddress, true);
  }

  function updateFee(uint256 feeType, uint256 fee) external onlyDev {
    require(fee <= 900, "OREO: The tax Fee cannot exceed 9%");

    // 1 = BUY FEE, 2 = SELL FEE, 3 = TREASURY FEE
    if (feeType == 1) {
      BUY_FEE = fee;
    } else if (feeType == 2) {
      SELL_FEE = fee;
    } else if (feeType == 3) {
      TREASURY_FEE = fee;
    }

    emit FeeUpdated(_msgSender(), feeType, fee);
  }

  function recoverToken(address _token) external onlyDev {
    uint256 tokenBalance = IERC20(_token).balanceOf(address(this));

    require(tokenBalance > 0, "OREO: The contract doen't have tokens to be recovered!");

    IERC20(_token).transfer(devAddress, tokenBalance);

    emit TokenRecoverd(devAddress, tokenBalance);
  }

  /***************************************************************************/
}
