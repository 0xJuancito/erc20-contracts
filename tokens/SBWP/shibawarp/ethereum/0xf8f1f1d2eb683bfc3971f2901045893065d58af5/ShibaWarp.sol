// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

library SafeMathInt {
    int256 private constant MIN_INT256 = int256(1) << 255;
    int256 private constant MAX_INT256 = ~(int256(1) << 255);

    function mul(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a * b;

        require(c != MIN_INT256 || (a & MIN_INT256) != (b & MIN_INT256));
        require((b == 0) || (c / b == a));
        return c;
    }

    function div(int256 a, int256 b) internal pure returns (int256) {
        require(b != -1 || a != MIN_INT256);

        return a / b;
    }

    function sub(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a - b;
        require((b >= 0 && c <= a) || (b < 0 && c > a));
        return c;
    }

    function add(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a + b;
        require((b >= 0 && c >= a) || (b < 0 && c < a));
        return c;
    }
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
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

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

interface IUniswapV2Pair {
  event Approval(address indexed owner, address indexed spender, uint value);
  event Transfer(address indexed from, address indexed to, uint value);

  function name() external pure returns (string memory);
  function symbol() external pure returns (string memory);
  function decimals() external pure returns (uint8);
  function totalSupply() external view returns (uint);
  function balanceOf(address owner) external view returns (uint);
  function allowance(address owner, address spender) external view returns (uint);

  function approve(address spender, uint value) external returns (bool);
  function transfer(address to, uint value) external returns (bool);
  function transferFrom(address from, address to, uint value) external returns (bool);

  function DOMAIN_SEPARATOR() external view returns (bytes32);
  function PERMIT_TYPEHASH() external pure returns (bytes32);
  function nonces(address owner) external view returns (uint);

  function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

  event Mint(address indexed sender, uint amount0, uint amount1);
  event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
  event Swap(
      address indexed sender,
      uint amount0In,
      uint amount1In,
      uint amount0Out,
      uint amount1Out,
      address indexed to
  );
  event Sync(uint112 reserve0, uint112 reserve1);

  function MINIMUM_LIQUIDITY() external pure returns (uint);
  function factory() external view returns (address);
  function token0() external view returns (address);
  function token1() external view returns (address);
  function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
  function price0CumulativeLast() external view returns (uint);
  function price1CumulativeLast() external view returns (uint);
  function kLast() external view returns (uint);

  function mint(address to) external returns (uint liquidity);
  function burn(address to) external returns (uint amount0, uint amount1);
  function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
  function skim(address to) external;
  function sync() external;
}

interface IUniswapV2Router01 {
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
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

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

interface IUniswapV2Factory {
  event PairCreated(address indexed token0, address indexed token1, address pair, uint);

  function getPair(address tokenA, address tokenB) external view returns (address pair);
  function allPairs(uint) external view returns (address pair);
  function allPairsLength() external view returns (uint);

  function feeTo() external view returns (address);
  function feeToSetter() external view returns (address);

  function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IDividendDistributor {
    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution) external;
    function setShare(address shareholder, uint256 amount) external;
    function deposit() external payable;
    function process(uint256 gas) external;
    function setMinimumSharesRequired(uint256 _minSharesRequired) external;
    function setSelllessSwapAddress(address _selllessSwap) external;
}

contract DividendDistributor is IDividendDistributor {
    using SafeMath for uint256;

    address public _token;

    struct Share {
        uint256 amount;
        uint256 totalExcluded;
        uint256 totalRealised;
    }

    IERC20 SHIBA = IERC20(0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE);
    IUniswapV2Router02 router;

    address selllessSwap;
    address[] shareholders;
    mapping (address => uint256) shareholderIndexes;
    mapping (address => uint256) shareholderClaims;

    mapping (address => Share) public shares;

    uint256 public totalShares;
    uint256 public totalDividends;
    uint256 public totalDistributed;
    uint256 public dividendsPerShare;
    uint256 public currentIndex;

    uint256 public constant dividendsPerShareAccuracyFactor = 10 ** 36;
    uint256 public minPeriod = 1 hours;
    uint256 public minDistribution = 1 * (10 ** 18);
    uint256 public minSharesRequired = 100;

    bool initialized;
    modifier initialization() {
        require(!initialized);
        _;
        initialized = true;
    }

    modifier onlyToken() {
        require(msg.sender == _token); _;
    }

    constructor (address _router) {
        router = _router != address(0)
        ? IUniswapV2Router02(_router)
        : IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        _token = msg.sender;
    }

    receive() external payable {}

    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution) external override onlyToken {
        minPeriod = _minPeriod;
        minDistribution = _minDistribution;
    }

    function setSelllessSwapAddress(address _selllessSwap) external override onlyToken {
        selllessSwap = _selllessSwap;
    }

    function setMinimumSharesRequired(uint256 _minSharesRequired) external override onlyToken {
        minSharesRequired = _minSharesRequired;
    }

    function setShare(address shareholder, uint256 amount) external override onlyToken {
        if(shares[shareholder].amount > minSharesRequired){
            distributeDividend(payable(shareholder));
        }

        if(amount > 0 && shares[shareholder].amount == 0){
            addShareholder(shareholder);
        }else if(amount == 0 && shares[shareholder].amount > 0){
            removeShareholder(shareholder);
        }

        totalShares = totalShares.sub(shares[shareholder].amount).add(amount);
        shares[shareholder].amount = amount;
        shares[shareholder].totalExcluded = getCumulativeDividends(shares[shareholder].amount);
    }

    function deposit() external payable override {
        uint256 balanceBefore = SHIBA.balanceOf(address(this));

        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(SHIBA);

        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: msg.value}(
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 amount = SHIBA.balanceOf(address(this)).sub(balanceBefore);

        totalDividends = totalDividends.add(amount);
        dividendsPerShare = dividendsPerShare.add(dividendsPerShareAccuracyFactor.mul(amount).div(totalShares));
    }

    function process(uint256 gas) external override onlyToken {
        uint256 shareholderCount = shareholders.length;

        if(shareholderCount == 0) { return; }

        uint256 gasUsed = 0;
        uint256 gasLeft = gasleft();
        uint256 iterations = 0;

        while(gasUsed < gas && iterations < shareholderCount) {
            if(currentIndex >= shareholderCount){
                currentIndex = 0;
            }

            if(shouldDistribute(shareholders[currentIndex])){
                distributeDividend(payable(shareholders[currentIndex]));
            }

            gasUsed = gasUsed.add(gasLeft.sub(gasleft()));
            gasLeft = gasleft();
            currentIndex++;
            iterations++;
        }
    }

    function shouldDistribute(address shareholder) internal view returns (bool) {
        return shareholderClaims[shareholder] + minPeriod < block.timestamp && getUnpaidEarnings(shareholder) > minDistribution;
    }

    function distributeDividend(address shareholder) internal {
        if(shares[shareholder].amount == 0){ return; }

        uint256 amount = getUnpaidEarnings(shareholder);
        if(amount > 0){
            totalDistributed = totalDistributed.add(amount);
            SHIBA.transfer(shareholder, amount);
            shareholderClaims[shareholder] = block.timestamp;
            shares[shareholder].totalRealised = shares[shareholder].totalRealised.add(amount);
            shares[shareholder].totalExcluded = getCumulativeDividends(shares[shareholder].amount);
        }
    }


    function claimDividend() external {
        distributeDividend(payable(msg.sender));
    }

    function getSelllessSwap() external view returns (address) {
        return selllessSwap;
    }

    function getUnpaidEarnings(address shareholder) public view returns (uint256) {
        if(shares[shareholder].amount == 0){ return 0; }

        uint256 shareholderTotalDividends = getCumulativeDividends(shares[shareholder].amount);
        uint256 shareholderTotalExcluded = shares[shareholder].totalExcluded;

        if(shareholderTotalDividends <= shareholderTotalExcluded){ return 0; }

        return shareholderTotalDividends.sub(shareholderTotalExcluded);
    }

    function getCumulativeDividends(uint256 share) internal view returns (uint256) {
        return share.mul(dividendsPerShare).div(dividendsPerShareAccuracyFactor);
    }

    function addShareholder(address shareholder) internal {
        shareholderIndexes[shareholder] = shareholders.length;
        shareholders.push(shareholder);
    }

    function removeShareholder(address shareholder) internal {
        shareholders[shareholderIndexes[shareholder]] = shareholders[shareholders.length-1];
        shareholderIndexes[shareholders[shareholders.length-1]] = shareholderIndexes[shareholder];
        shareholders.pop();
    }
}

abstract contract Ownable {
    address private _owner;

    event OwnershipRenounced(address indexed previousOwner);

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        _owner = msg.sender;
    }

    function owner() external view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(isOwner());
        _;
    }

    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    function renounceOwnership() external onlyOwner {
        emit OwnershipRenounced(_owner);
        _owner = address(0);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

abstract contract ERC20Detailed is IERC20 {
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }
}

contract ShibaWarp is ERC20Detailed, Ownable {

    using SafeMath for uint256;
    using SafeMathInt for int256;

    IUniswapV2Pair public pairContract;
    mapping(address => bool) _isFeeExempt;    

    IUniswapV2Router02 public immutable router;

    IERC20 constant SHIBA = IERC20(0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE);
    IERC20 public NFT = IERC20(0x0000000000000000000000000000000000000000);


    uint256 public constant DECIMALS = 18;

    uint256 public utilityBuyFee = 0;
    uint256 public utilitySellFee = 10;
    uint256 public rewardDividendBuyFee = 10;
    uint256 public rewardDividendSellFee = 20;
    uint256 public shibaBurnBuyFee = 10;
    uint256 public shibaBurnSellFee = 20;
    uint256 public buybackBuyFee = 10;
    uint256 public buybackSellFee = 20;
    uint256 public totalBuyFee = utilityBuyFee.add(rewardDividendBuyFee).add(shibaBurnBuyFee).add(buybackBuyFee);
    uint256 public totalSellFee = utilitySellFee.add(rewardDividendSellFee).add(shibaBurnSellFee.add(buybackSellFee));
    uint256 public constant feeDenominator = 1000;
    uint256 public _swapEnabledTime;
    uint256 public _totalSupply = 375000000 * 10**DECIMALS;
    uint256 public maxWallet;

    //addresses
    address constant DEAD = 0xdEAD000000000000000042069420694206942069;
    address constant ZERO = 0x0000000000000000000000000000000000000000;
    address payable public utilityReceiver;
    address payable public buybackReceiver;
    address public selllessSwap;

    DividendDistributor  distributor;
    address payable public  DividendReceiver;
    uint256 distributorGas = 500000;
    uint256 public minSharesRequired = 100;

    address public  pair;
    bool inSwap = false;
    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }

    bool public _swapEnabled = false;

    //mapping
    mapping(address => bool) public isDividendExempt;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => uint256) private _tOwned;




    //events
    event FeesChanged(uint256 buybackBuyFee, uint256 SHIBADividendFee, uint256 SHIBABurnBuyFee,  uint256 utilityBuyFee);
    event SellFeesChanged(uint256 buybackSellFee, uint256 SHIBADividendFee, uint256 SHIBABurnSellFee, uint256 utilitySellFee);
    event minShresRequiredChanged(uint256 minSharesRequired);
    event SwapEnabled(bool swapEnabled);
    event FeeReceiversChanged(address utilityReceiver, address buybackReceiver);

    constructor() ERC20Detailed("ShibaWarp", "SBWP", uint8(DECIMALS)) Ownable() {

        //mainnet
        router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D); 
        pair = IUniswapV2Factory(router.factory()).createPair(
            router.WETH(),
            address(this)
        );

        address shibaPair = IUniswapV2Factory(router.factory()).getPair(router.WETH(), address(SHIBA));
        require(shibaPair != address(0), "Uniswap pair does not exist!");

        
        buybackReceiver = payable(0x15E7C78756566f08F06F5639c0FBB5ED2FE588cB);  
        utilityReceiver = payable(0x15E7C78756566f08F06F5639c0FBB5ED2FE588cB);   
 
     
        pairContract = IUniswapV2Pair(pair);

        distributor = new DividendDistributor(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        DividendReceiver = payable(address(distributor));
        

        //dividend exempt accounts
        isDividendExempt[msg.sender] = true;
        isDividendExempt[pair] = true;
        isDividendExempt[address(this)] = true;
        isDividendExempt[DEAD] = true;
        isDividendExempt[ZERO] = true;
        isDividendExempt[utilityReceiver] = true;
        isDividendExempt[buybackReceiver] = true;

        _swapEnabledTime = block.timestamp;
        maxWallet = (2 * _totalSupply) / 100;

        //fee exempt accounts
        _isFeeExempt[utilityReceiver] = true;
        _isFeeExempt[buybackReceiver] = true;
        _isFeeExempt[address(this)] = true;
        _isFeeExempt[msg.sender] = true;

        emit Transfer(address(0x0), msg.sender, _totalSupply);
        _tOwned[msg.sender] = _totalSupply;
    }


    function transfer(address to, uint256 value)
        external
        override
        returns (bool)
    {
        _transferFrom(msg.sender, to, value);
        return true;
    }    

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external override returns (bool) {
        
        if (_allowances[from][msg.sender] != type(uint128).max) {
            _allowances[from][msg.sender] = _allowances[from][
                msg.sender
            ].sub(value, "Insufficient Allowance");
        }
        _transferFrom(from, to, value);
        return true;
    }

    function _basicTransfer(
        address from,
        address to,
        uint256 amount
    ) internal returns (bool) {
        _tOwned[from] = _tOwned[from].sub(amount);
        _tOwned[to] = _tOwned[to].add(amount);
        return true;
    }

    function _transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        if(recipient != pair){
            if(!_isFeeExempt[recipient]){
                require(_tOwned[recipient] + amount <= maxWallet, "transaction would exceed max wallet size");
            }
        }

        if(!_swapEnabled){
            require(_isFeeExempt[sender] || _isFeeExempt[recipient], "trading is not enabled yet");
        }

        if (inSwap) {
            return _basicTransfer(sender, recipient, amount);
        }

        if (shouldSwapBack()) {
            swapBack();
        }

        _tOwned[sender] = _tOwned[sender].sub(amount);
        uint256 amountReceived = shouldTakeFee(sender, recipient)
            ? takeFee(sender, recipient, amount)
            : amount;
        _tOwned[recipient] = _tOwned[recipient].add(
            amountReceived
        );

        if(!isDividendExempt[sender]){ try distributor.setShare(sender, balanceOf(sender)) {} catch {} }
        if(!isDividendExempt[recipient]){ try distributor.setShare(recipient, balanceOf(recipient)) {} catch {} }

        try distributor.process(distributorGas) {} catch {}

        emit Transfer(
            sender,
            recipient,
            amountReceived
        );
        return true;
    }

    function takeFee(
        address sender,
        address recipient,
        uint256 amount
    ) internal  returns (uint256) {
        uint256 _totalFee = totalBuyFee;

        if (recipient == pair) {
            _totalFee = totalSellFee;
        }

        // Check if the sender has the NFT balance
        if (getNFTBalance(recipient) == true){

            // If the sender has the NFT, reduce the buy fee by 1%
            if (sender == pair) {
                if(_totalFee > 0){
                _totalFee = _totalFee.sub(10);
                }
            }
        }

        uint256 feeAmount = amount.mul(_totalFee).div(feeDenominator);
        if(_isFeeExempt[sender] || _isFeeExempt[recipient]){
            feeAmount = 0;
        }
       
        _tOwned[address(this)] = _tOwned[address(this)].add(feeAmount);
        
        if(feeAmount > 0){
            emit Transfer(sender, address(this), feeAmount);
        }
        return amount.sub(feeAmount);
    }

    function swapBack() internal swapping {

        uint256 totalFee = totalSellFee.add(totalBuyFee);

        if(totalFee == 0) {
            totalFee = 1;
        }

        uint256 amountToSwap = _tOwned[address(this)];

        if( amountToSwap == 0) {
            return;
        }

        _allowances[address(this)][address(router)] = amountToSwap;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();
        
        bool swapTokensForETHSuccess = false;
        try router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToSwap,
            0,
            path,
            address(this),
            block.timestamp
        ) {
            swapTokensForETHSuccess = true;
        } catch {}

        uint256 totalReceived = address(this).balance;

        uint256 totalRewardFee = (rewardDividendBuyFee.add(rewardDividendSellFee));

        uint256 totalShibaBurnFee = shibaBurnBuyFee.add(shibaBurnSellFee);

        uint256 totalBuybackFee = buybackBuyFee.add(buybackSellFee);

        uint256 portionToDistributor = totalReceived.mul(totalRewardFee).div(totalFee);

        uint256 portionToBuyback = totalReceived.mul(totalBuybackFee).div(totalFee);

        uint256 portionToShibaBurn = totalReceived.mul(totalShibaBurnFee).div(totalFee);

        uint256 portionToUtility = totalReceived.sub(portionToBuyback).sub(portionToDistributor).sub(portionToShibaBurn);

        address[] memory shibaPath = new address[](2);
        shibaPath[0] = router.WETH();
        shibaPath[1] = address(SHIBA);

        bool swapETHForTokensSuccess = false;
        try router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: portionToShibaBurn}(
            0,
            shibaPath,
            DEAD,
            block.timestamp
        ) {
            swapETHForTokensSuccess = true;
        } catch {}
        
        // Try to deposit into distributor
        bool distributorDepositSuccess = false;
        try distributor.deposit{value: portionToDistributor}() {
            distributorDepositSuccess = true;
        } catch {}

        (bool success, ) = utilityReceiver.call{value: portionToUtility}("");
        require(success, "Utility transfer failed");

        (bool buybacksuccess, ) = buybackReceiver.call{value: portionToBuyback}("");
        require(buybacksuccess, "buyback transfer failed");
        
    }

    function shouldTakeFee(address from, address to)
        internal
        view
        returns (bool)
    {
        return 
            (pair == from || pair == to) &&
            (!_isFeeExempt[from] || !_isFeeExempt[to]);
    }

    function shouldSwapBack() internal view returns (bool) {
        return 
            !inSwap &&
            msg.sender != pair  ; 
    }

    function allowance(address owner_, address spender)
        external
        view
        override
        returns (uint256)
    {
        return _allowances[owner_][spender];
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        returns (bool)
    {
        uint256 oldValue = _allowances[msg.sender][spender];
        if (subtractedValue >= oldValue) {
            _allowances[msg.sender][spender] = 0;
        } else {
            _allowances[msg.sender][spender] = oldValue.sub(
                subtractedValue
            );
        }
        emit Approval(
            msg.sender,
            spender,
            _allowances[msg.sender][spender]
        );
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        external
        returns (bool)
    {
        _allowances[msg.sender][spender] = _allowances[msg.sender][
            spender
        ].add(addedValue);
        emit Approval(
            msg.sender,
            spender,
            _allowances[msg.sender][spender]
        );
        return true;
    }

    function approve(address spender, uint256 value)
        public
        override
        returns (bool)
    {
        _allowances[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(amount != 0);
        require(amount <= _tOwned[account]);
        _totalSupply = _totalSupply.sub(amount);
        _tOwned[account] = _tOwned[account].sub(amount);
        emit Transfer(account, address(0), amount);
    }

    function setEnableSwap() external onlyOwner {
        _swapEnabled = true;
        _swapEnabledTime = block.timestamp;
        
        emit SwapEnabled(_swapEnabled);

    }

    function setIsDividendExempt(address holder, bool exempt) external onlyOwner {
        require(holder != address(this) && holder != pair);
        isDividendExempt[holder] = exempt;

        if (exempt) {
            distributor.setShare(holder, 0);
        } else {
            distributor.setShare(holder, balanceOf(holder));
        }
    }

    function setSelllessSwapAddress(address _selllessSwap) external onlyOwner {
        distributor.setSelllessSwapAddress(_selllessSwap);

        selllessSwap == _selllessSwap;

        _isFeeExempt[_selllessSwap] = true;
    }

    function setMaxWallet(uint256 _maxWallet) external onlyOwner{
        require(_maxWallet >= 1, "Max wallet must be greater than 0.01% of Total Supply");
        maxWallet = (_maxWallet * _totalSupply) / 10000;
    }

    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution) external onlyOwner {
        distributor.setDistributionCriteria(_minPeriod, _minDistribution);
    }

    function setDistributorSettings(uint256 gas) external onlyOwner {
        require(gas < 750000, "Gas must be lower than 750000");
        distributorGas = gas;
    }

    function setMinimumSharesRequired(uint256 _minSharesRequired) external onlyOwner {
        minSharesRequired = _minSharesRequired;

        emit minShresRequiredChanged(_minSharesRequired);
    }


    function setBuyFees(uint256 _buybackFee, uint256 _shibaDividendFee, uint256 _shibaBurnBuyFee, uint256 _utilityFee) external onlyOwner {
        buybackBuyFee = _buybackFee;
        rewardDividendBuyFee = _shibaDividendFee;
        shibaBurnBuyFee = _shibaBurnBuyFee;
        
        utilityBuyFee = _utilityFee;

        totalBuyFee = buybackBuyFee.add(rewardDividendBuyFee).add(shibaBurnBuyFee);
        require(totalBuyFee <= 250, "Must keep fees at 25% or less");

        emit FeesChanged(_buybackFee, _shibaDividendFee, _shibaBurnBuyFee, _utilityFee);
    }

    function setSellFees(uint256 _buybackFee, uint256 _shibaDividendFee, uint256 _shibaBurnSellFee, uint256 _utilityFee) external onlyOwner {
        buybackSellFee = _buybackFee;
        rewardDividendSellFee = _shibaDividendFee;
        shibaBurnSellFee = _shibaBurnSellFee;
        utilitySellFee = _utilityFee;

        totalSellFee = buybackSellFee.add(rewardDividendSellFee).add(shibaBurnSellFee).add(utilitySellFee);
        require(totalSellFee <= 250, "Must keep fees at 25% or less");

        emit SellFeesChanged(_buybackFee, _shibaDividendFee, _shibaBurnSellFee, _utilityFee);
    }

    function setFeeReceivers(
        address _utilityReceiver,
        address _buybackReceiver
    ) external onlyOwner {
        utilityReceiver = payable(_utilityReceiver);
        buybackReceiver = payable(_buybackReceiver);

        emit FeeReceiversChanged( _utilityReceiver, _buybackReceiver);      
    }

    function setWhitelist(address _addr) external onlyOwner {
        _isFeeExempt[_addr] = true;
    }

    function setLP(address _address) external onlyOwner {
        pairContract = IUniswapV2Pair(_address);
    }

    function setNFTContract(address _NFT) external onlyOwner {
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(_NFT)
        }

        // Ensure _NFT is a contract
        require(codeSize > 0, "Given address is not a contract");

        NFT = IERC20(_NFT);
    }
    
    //getters
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }
   
    function balanceOf(address account) public view override returns (uint256) {
        return _tOwned[account];
    }

    function checkFeeExempt(address _addr) external view returns (bool) {
        return _isFeeExempt[_addr];
    }

    function isNotInSwap() external view returns (bool) {
        return !inSwap;
    }

    function getNFTBalance(address account) public view returns (bool) {
        if (address(NFT) == address(0)) {
            return false;  // return false if NFT address hasn't been set
        }

        (bool success, bytes memory data) = address(NFT).staticcall(abi.encodeWithSignature("balanceOf(address)", account));
    
        if (!success) {
            return false;  // Handle failed calls by returning false
        }

        uint256 balance = abi.decode(data, (uint256));
        if (balance >= 1) {
            return true;
        }       

        return false;
    }

    //utility extrasa

    //get sstuck tokens ftom contract
    function rescueToken(address tokenAddress, address to) external onlyOwner returns (bool success) {
        uint256 _contractBalance = IERC20(tokenAddress).balanceOf(address(this));

      
        return IERC20(tokenAddress).transfer(to, _contractBalance);
    }

    //gets stuck bnb from contract
    function rescueBNB(uint256 amount) external onlyOwner{
    payable(msg.sender).transfer(amount);
    }

    receive() external payable {}
}