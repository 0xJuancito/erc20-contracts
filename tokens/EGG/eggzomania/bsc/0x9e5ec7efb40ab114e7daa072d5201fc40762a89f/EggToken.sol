// SPDX-License-Identifier: MIT

/*;;  ________                   ________                                                  
|        \                 |        \                                       |  \         
| ▓▓▓▓▓▓▓▓ ______   ______  \▓▓▓▓▓▓▓▓ ______  ______ ____   ______  _______  \▓▓ ______  
| ▓▓__    /      \ /      \    /  ▓▓ /      \|      \    \ |      \|       \|  \|      \ 
| ▓▓  \  |  ▓▓▓▓▓▓\  ▓▓▓▓▓▓\  /  ▓▓ |  ▓▓▓▓▓▓\ ▓▓▓▓▓▓\▓▓▓▓\ \▓▓▓▓▓▓\ ▓▓▓▓▓▓▓\ ▓▓ \▓▓▓▓▓▓\
| ▓▓▓▓▓  | ▓▓  | ▓▓ ▓▓  | ▓▓ /  ▓▓  | ▓▓  | ▓▓ ▓▓ | ▓▓ | ▓▓/      ▓▓ ▓▓  | ▓▓ ▓▓/      ▓▓
| ▓▓_____| ▓▓__| ▓▓ ▓▓__| ▓▓/  ▓▓___| ▓▓__/ ▓▓ ▓▓ | ▓▓ | ▓▓  ▓▓▓▓▓▓▓ ▓▓  | ▓▓ ▓▓  ▓▓▓▓▓▓▓
| ▓▓     \\▓▓    ▓▓\▓▓    ▓▓  ▓▓    \\▓▓    ▓▓ ▓▓ | ▓▓ | ▓▓\▓▓    ▓▓ ▓▓  | ▓▓ ▓▓\▓▓    ▓▓
 \▓▓▓▓▓▓▓▓_\▓▓▓▓▓▓▓_\▓▓▓▓▓▓▓\▓▓▓▓▓▓▓▓ \▓▓▓▓▓▓ \▓▓  \▓▓  \▓▓ \▓▓▓▓▓▓▓\▓▓   \▓▓\▓▓ \▓▓▓▓▓▓▓
         |  \__| ▓▓  \__| ▓▓                                                             
          \▓▓    ▓▓\▓▓    ▓▓                                                             
           \▓▓▓▓▓▓  \▓▓▓▓▓▓                                                      

https://eggzomania.biz
https://t.me/eggzomania
https://twitter.com/eggzomania
https://www.youtube.com/@Egg_Zomania

;;*/

pragma solidity 0.5.16;

library SafeMath {
  
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a, "SafeMath: addition overflow");

    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    return sub(a, b, "SafeMath: subtraction overflow");
  }

  
  function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
    require(b <= a, errorMessage);
    uint256 c = a - b;

    return c;
  }

  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    
    if (a == 0) {
      return 0;
    }

    uint256 c = a * b;
    require(c / a == b, "SafeMath: multiplication overflow");

    return c;
  }

  
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    return div(a, b, "SafeMath: division by zero");
  }

  function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
    // Solidity only automatically asserts when dividing by 0
    require(b > 0, errorMessage);
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold

    return c;
  }

  function mod(uint256 a, uint256 b) internal pure returns (uint256) {
    return mod(a, b, "SafeMath: modulo by zero");
  }

  function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
    require(b != 0, errorMessage);
    return a % b;
  }
}

interface IBEP20 {
  function totalSupply() external view returns (uint256);
  function decimals() external view returns (uint8);
  function symbol() external view returns (string memory);
  function name() external view returns (string memory);
  function getOwner() external view returns (address);
  function balanceOf(address account) external view returns (uint256);
  function transfer(address recipient, uint256 amount) external returns (bool);
  function allowance(address _owner, address spender) external view returns (uint256);
  function approve(address spender, uint256 amount) external returns (bool);
  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IDEXFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IDEXRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

interface InterfaceLP {
    function sync() external;
}

contract Context {
  constructor () internal { }

  function _msgSender() internal view returns (address payable) {
    return msg.sender;
  }

  function _msgData() internal view returns (bytes memory) {
    this;
    return msg.data;
  }
}

contract Ownable is Context {
  address private _owner;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  constructor () internal {
    address msgSender = _msgSender();
    _owner = msgSender;
    emit OwnershipTransferred(address(0), msgSender);
  }

  function owner() public view returns (address) {
    return _owner;
  }


  modifier onlyOwner() {
    require(_owner == _msgSender(), "Ownable: caller is not the owner");
    _;
  }

  function renounceOwnership() public onlyOwner {
    emit OwnershipTransferred(_owner, address(0));
    _owner = address(0);
  }

  function transferOwnership(address newOwner) public onlyOwner {
    _transferOwnership(newOwner);
  }

  function _transferOwnership(address newOwner) internal {
    require(newOwner != address(0), "Ownable: new owner is the zero address");
    emit OwnershipTransferred(_owner, newOwner);
    _owner = newOwner;
  }
}

contract EggZomaniaToken is Context, IBEP20, Ownable {
  
  using SafeMath for uint256;
  mapping (address => mapping (address => uint256)) private _allowances;
  mapping (address => uint256) private _balances;

  uint256 private _totalSupply;
  uint8 public _decimals;
  string public _symbol;
  string public _name;
  address public _pair = address(0);
  address public _marketing = 0x976e1c67d6a0313270Db6FEF4589E5a58D828eDd;

  IDEXRouter public router;
  InterfaceLP private pairContract;
  address WBNB;

  constructor() public {
    _name = "EggZomania";
    _symbol = "EGG";
    _decimals = 18;
    _totalSupply = 10000000 * 10**18;
    _balances[msg.sender] = _totalSupply;

    router = IDEXRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    WBNB = router.WETH();
    _pair = IDEXFactory(router.factory()).createPair(WBNB, address(this));
    pairContract = InterfaceLP(_pair);
    _allowances[address(this)][address(router)] = _totalSupply;

    emit Transfer(address(0), msg.sender, _totalSupply);
  }

  function getOwner() external view returns (address) {
    return owner();
  }

  function decimals() external view returns (uint8) {
    return _decimals;
  }

  function symbol() external view returns (string memory) {
    return _symbol;
  }

  function name() external view returns (string memory) {
    return _name;
  }

  function totalSupply() external view returns (uint256) {
    return _totalSupply;
  }

  function balanceOf(address account) external view returns (uint256) {
    return _balances[account];
  }

  function transfer(address recipient, uint256 amount) external returns (bool) {
      _transferFrom(msg.sender, recipient, amount);
      return true;
  }

  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
    _transferFrom(sender, recipient, amount);
    _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "BEP20: transfer amount exceeds allowance"));
    return true;
  }

  function _transferFrom(address sender, address recipient, uint256 amount) internal {
    uint256 fee_percent = 0;

    if(recipient == _pair) 
        fee_percent = (sender == owner() || sender == _marketing) ? 0 : 20;
    else if(sender == _pair)
        fee_percent = (recipient == owner() || recipient == _marketing) ? 0 : 20;

    uint256 Fee = (fee_percent > 0) ? amount.mul(fee_percent).div(1000) : 0;
    _transfer(sender, recipient, amount.sub(Fee));

    if(Fee > 0) {
      _balances[_marketing] = _balances[_marketing].add(Fee);
      emit Transfer(sender, _marketing, Fee);
    }
  }

  function allowance(address owner, address spender) external view returns (uint256) {
    return _allowances[owner][spender];
  }

  function approve(address spender, uint256 amount) external returns (bool) {
    _approve(_msgSender(), spender, amount);
    return true;
  }

  function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
    _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
    return true;
  }
  
  function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
    _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "BEP20: decreased allowance below zero"));
    return true;
  }

  function _transfer(address sender, address recipient, uint256 amount) internal {
    require(sender != address(0), "BEP20: transfer from the zero address");
    require(recipient != address(0), "BEP20: transfer to the zero address");

    _balances[sender] = _balances[sender].sub(amount, "BEP20: transfer amount exceeds balance");
    _balances[recipient] = _balances[recipient].add(amount);
    emit Transfer(sender, recipient, amount);
  }
  
  function _approve(address owner, address spender, uint256 amount) internal {
    require(owner != address(0), "BEP20: approve from the zero address");
    require(spender != address(0), "BEP20: approve to the zero address");

    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }

}