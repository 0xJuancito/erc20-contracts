/*
░██╗░░░░░░░██╗██╗░░██╗██╗░██████╗██████╗░███████╗██████╗░
░██║░░██╗░░██║██║░░██║██║██╔════╝██╔══██╗██╔════╝██╔══██╗
░╚██╗████╗██╔╝███████║██║╚█████╗░██████╔╝█████╗░░██████╔╝
░░████╔═████║░██╔══██║██║░╚═══██╗██╔═══╝░██╔══╝░░██╔══██╗
░░╚██╔╝░╚██╔╝░██║░░██║██║██████╔╝██║░░░░░███████╗██║░░██║
░░░╚═╝░░░╚═╝░░╚═╝░░╚═╝╚═╝╚═════╝░╚═╝░░░░░╚══════╝╚═╝░░╚═╝
*/
// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;
pragma experimental ABIEncoderV2;

abstract contract Ownable {
    address private _owner;

    constructor() {
        _owner = msg.sender;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) external virtual payable onlyOwner {
        _owner = newOwner;
    }
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external;
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router02 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external;

    function addLiquidityETH(address token, uint256 amountTokenDesired, uint256 amountTokenMin, uint256 amountETHMin, address to, uint256 deadline) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
}

contract WhisperToken is Ownable {
    string private constant _name = "WhisperBot";
    string private constant _symbol = "WSP";
    uint256 private constant _totalSupply = 10_000_000 * 1e18;

    uint256 public maxWallet = 1_000_000 * 1e18;
    uint256 public swapTokensAtAmount = (_totalSupply * 1) / 1000;

    address private holdersWallet = 0xeAadC47042E35A6b0F896362dc1fdabD3E1611a9;
    address private teamWallet = 0xB00a3954D6215F030e0D9A425555bdb13652e910;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    uint8 public buyTotalFees = 50;
    uint8 public sellTotalFees = 50;

    uint8 public lpFee = 30;
    uint8 public holdersFee = 20;
    uint8 public teamFee = 50;

    bool private swapping;
    bool public limitsInEffect = true;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) private automatedMarketMakerPairs;

    event SwapAndLiquify(uint256 tokens, uint256 lpTokens, uint256 holdersETH, uint256 teamETH);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    IUniswapV2Router02 public constant uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address public immutable uniswapV2Pair;
    uint256 public immutable lockEndTime;

    constructor() payable {
        setExcludedFromFees(address(this), true);

        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), WETH);
        automatedMarketMakerPairs[uniswapV2Pair] = true;
        lockEndTime = block.timestamp + 180 days;

        _balances[address(this)] = _totalSupply;
        emit Transfer(address(0), address(this), _balances[address(this)]);

        _approve(address(this), address(uniswapV2Router), type(uint256).max);
    }

    receive() external payable {}

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function totalSupply() public pure returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external {
        _approve(msg.sender, spender, amount);
    }

    function _approve(address owner, address spender, uint256 amount ) private {
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function transfer(address recipient, uint256 amount) external {
        _transfer(msg.sender, recipient, amount);
    }

    function transferFrom(address sender, address recipient,uint256 amount) external {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][msg.sender];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, msg.sender, currentAllowance - amount);
        }
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(to != address(0), "ERC20: transfer to the zero address");

        if (limitsInEffect) {
            if (to != address(this) && to != address(uniswapV2Pair)) {
                require(amount + balanceOf(to) <= maxWallet, "Max wallet exceeded");
            }
        }

        bool canSwap = balanceOf(address(this)) >= swapTokensAtAmount;

        if (canSwap && !swapping && !automatedMarketMakerPairs[from] && !_isExcludedFromFees[from] && !_isExcludedFromFees[to]) {
            swapping = true;
            swapBack();
            swapping = false;
        }

        bool takeFee = !swapping;

        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }

        uint256 fees = 0;
        if (takeFee) {
            if (automatedMarketMakerPairs[to] && sellTotalFees > 0) {
                fees = (amount * sellTotalFees) / 1000;
            } else if (automatedMarketMakerPairs[from] && buyTotalFees > 0) {
                fees = (amount * buyTotalFees) / 1000;
            }

            if (fees > 0) {
                amount = amount - fees;
                unchecked {
                    _balances[address(this)] += fees;
                }
                emit Transfer(from, address(this), fees);
            }
        }

        uint256 senderBalance = _balances[from];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = senderBalance - amount;
            _balances[to] += amount - fees;
        }

        emit Transfer(from, to, amount);
    }

    function removeLimits() external payable onlyOwner {
        limitsInEffect = false;
    }

    function setDistributionFees(uint8 _lpFee, uint8 _holdersFee, uint8 _teamFee) external payable onlyOwner {
        require((_lpFee + _holdersFee + _teamFee) == 100, "Distribution have to be equal to 100%");
        lpFee = _lpFee;
        holdersFee = _holdersFee;
        teamFee = _teamFee;
    }

    function setFees(uint8 _buyTotalFees, uint8 _sellTotalFees) external payable onlyOwner {
        require(_buyTotalFees <= 50, "Buy fees must be less than or equal to 5%");
        require(_sellTotalFees <= 50, "Sell fees must be less than or equal to 5%");
        buyTotalFees = _buyTotalFees;
        sellTotalFees = _sellTotalFees;
    }

    function setExcludedFromFees(address account, bool excluded) public payable onlyOwner {
        _isExcludedFromFees[account] = excluded;
    }

    function start() external payable onlyOwner {
        uniswapV2Router.addLiquidityETH{value: msg.value}(
            address(this),
            _totalSupply,
            0,
            0,
            address(this),
            block.timestamp
        );
    }

    function setAutomatedMarketMakerPair(address pair, bool value) public payable onlyOwner {
        require(pair != address(uniswapV2Pair), "The pair cannot be removed");
        automatedMarketMakerPairs[pair] = value;
    }

    function setSwapAtAmount(uint256 newSwapAmount) external payable onlyOwner {
        swapTokensAtAmount = newSwapAmount;
    }

    function setMaxWalletAmount(uint256 newMaxWallet) external payable onlyOwner {
        maxWallet = newMaxWallet * (10**18);
    }

    function updateHoldersWallet(address newAddress) external payable onlyOwner {
        require(newAddress != address(0));
        holdersWallet = newAddress;
    }

    function updateTeamWallet(address newAddress) external payable onlyOwner {
        require(newAddress != address(0));
        teamWallet = newAddress;
    }

    function excludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFees[account];
    }

    function withdrawStuckToken(address token, address to) external payable onlyOwner {
        if (token == address(uniswapV2Pair)) {
            require(block.timestamp > lockEndTime, "Liquidity is locked");
        }
        uint256 _contractBalance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(to, _contractBalance);
    }

    function withdrawStuckETH(address addr) external payable onlyOwner {
        require(addr != address(0), "Invalid address");

        (bool success, ) = addr.call{value: address(this).balance}("");
        require(success, "Withdrawal failed");
    }

    function swapBack() private {
        uint256 swapThreshold = swapTokensAtAmount;
        bool success;

        if (balanceOf(address(this)) > swapTokensAtAmount * 20) {
            swapThreshold = swapTokensAtAmount * 20;
        }

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WETH;

        uint256 tokensForLp = (swapThreshold * lpFee / 2) / 100;
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(swapThreshold - tokensForLp, 0, path, address(this), block.timestamp);
        uint256 ethBalance = address(this).balance;
        uniswapV2Router.addLiquidityETH{value: (ethBalance * lpFee / 2) / (100 - lpFee / 2)}(
            address(this),
            tokensForLp,
            0,
            0,
            address(this),
            block.timestamp
        );

        
        if (ethBalance > 0) {
            uint256 ethForHolders = (ethBalance * holdersFee) / (100 - lpFee / 2);
            uint256 ethForTeam = (ethBalance * teamFee) / (100 - lpFee / 2);

            (success, ) = address(holdersWallet).call{value: ethForHolders}("");
            (success, ) = address(teamWallet).call{value: ethForTeam}("");

            emit SwapAndLiquify(swapThreshold, tokensForLp, ethForHolders, ethForTeam);
        }
    }
}