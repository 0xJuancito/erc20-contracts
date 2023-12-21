/**
    Patriot Pay:
    Initial Supply: 40,000,000,000 (40 Billion)
*/

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
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

contract PPY is Initializable, ERC20Upgradeable, OwnableUpgradeable  {
    using SafeMathUpgradeable for uint256;

    mapping (address => bool) private _excludedFromFee;
    mapping (address => bool) public  preTrader;
    mapping (address => bool) private _VIPWallet;
    mapping (address => bool) private _blacklist;
    mapping (address => bool) public excludedFromAntibot;

    uint256 private _totalSupply;
    
    uint8 public buyCharityCommunityFee;
    uint8 public buyOperationsFee;
    uint8 public buyLPFee;
    uint8 public buyTeamFees;

    uint8 public sellCharityCommunityFee ;
    uint8 public sellOperationsFee;
    uint8 public sellLPFee;
    uint8 public sellTeamFees;

    uint8 public transferCharityCommunityFee;
    uint8 public transferOperationsFee;
    uint8 public transferLPFee;
    uint8 public transferTeamFees;

    // Fee for VIP
    uint8 public transferCharityCommunityFeeForVIP;
    uint8 public transferOperationsFeeForVIP;
    uint8 public transferLPFeeForVIP;
    uint8 public transferTeamFeesForVIP;

    // Antibot Fee for Sell
    uint8 public sellCharityCommunityFeeForAntibot;
    uint8 public sellOperationsFeeForAntibot;
    uint8 public sellLPFeeForAntibot;
    uint8 public sellTeamFeesForAntibot;

    uint256 public tokensForCharityCommunity;
    uint256 public tokensForOperations;
    uint256 public tokensForLP;

    // Antibot Fee Time
    uint256 public _antibotFeeTime; // by seconds units
    mapping (address => uint256) private _holderFirstBuyTimestamp;

    IUniswapV2Router02 public  uniswapV2Router;
    address public  uniswapV2Pair;
    address public stableTokenAddress;  // The address of the stable token

    address private constant SWAP_V2_ROUTER = address(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);
    address payable public charityCommunityAddress;
    address payable public operationsAddress;
    
    uint256 public maxTxAmount;
    uint256 public minAmountToSwap;

    bool public isTradingEnabled ;
    bool private _isSwapping;
    bool public isAutoSwapEnabledForTeam ;
    bool public isAutoSwapEnabledForVIP ;
    bool public isAntibotEnabled;

    event SetAutoSwapEnabled(bool status);
    event SetAutoSwapEnabledForVIP(bool status);
    event AddLiquidity(uint256 contractTokens, uint256 tokensSwapped);

    modifier lockSwap {
        _isSwapping = true;
        _;
        _isSwapping = false;
    }

    //to recieve MATIC
    receive() external payable {}

    function initialize() public initializer {
        // Initialize the ERC20 token with a name and symbol
        __ERC20_init("Patriot Pay", "PPY");

        // Initialize other state variables and settings here
        _totalSupply = 40000000000 * 10**18;
        buyCharityCommunityFee = 1;
        buyOperationsFee = 5;
        buyLPFee = 2;
        sellCharityCommunityFee = 1;
        sellOperationsFee = 5;
        sellLPFee = 2;
        
        transferCharityCommunityFee = 1;
        transferOperationsFee = 5;
        transferLPFee = 2;

        // Fee for VIP
        transferCharityCommunityFeeForVIP = 1;
        transferOperationsFeeForVIP = 5;
        transferLPFeeForVIP = 2;

        // Antibot Fee for Sell
        sellCharityCommunityFeeForAntibot = 8;
        sellOperationsFeeForAntibot = 20;
        sellLPFeeForAntibot = 2;

        _antibotFeeTime = 86400; 

        maxTxAmount = 100000000 * 10**18;
        minAmountToSwap = 1000000;

        isTradingEnabled = false;
        _isSwapping = false;
        isAutoSwapEnabledForTeam = false;
        isAutoSwapEnabledForVIP = false;
        isAntibotEnabled = true;

        charityCommunityAddress = payable(0x92666f8161F2F204E55E2A77223Bc2655468723F);
        operationsAddress = payable(0x3731fB024964d0c7a189e95C3Da7DABAdc275C9d);        

        // Mint the initial supply to the deployer
        uniswapV2Router = IUniswapV2Router02(SWAP_V2_ROUTER);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());
        _transferOwnership(0xba8bD6A7aA2F6050b7Cd14e0B195B1905dDed677);
        stableTokenAddress = address(0xc2132D05D31c914a87C6611C10748AEb04B58e8F); // USDT address as default

        buyTeamFees = buyCharityCommunityFee + buyOperationsFee + buyLPFee;
        sellTeamFees = sellCharityCommunityFee + sellOperationsFee + sellLPFee;
        sellTeamFeesForAntibot = sellCharityCommunityFeeForAntibot + sellOperationsFeeForAntibot + sellLPFeeForAntibot;
        transferTeamFees = transferCharityCommunityFee + transferOperationsFee + transferLPFee;
        transferTeamFeesForVIP = transferCharityCommunityFeeForVIP + transferOperationsFeeForVIP + transferLPFeeForVIP;
       
        //exclude owner and this contract from fee
        _excludedFromFee[owner()] = true;
        _excludedFromFee[address(this)] = true;

        preTrader[owner()] = true;
        preTrader[address(this)] = true;

        _mint(0xba8bD6A7aA2F6050b7Cd14e0B195B1905dDed677, _totalSupply);
    }

    function enableTrading(bool status) external onlyOwner {
        isTradingEnabled = status;
    }

    function managePreTrading(address account, bool status) external onlyOwner {
        preTrader[account] = status;
    }

    function excludeWalletFromAntibot(address account, bool status) external onlyOwner {
        excludedFromAntibot[account] = status;
    }

    function isExcludedFromFee(address account) external view returns(bool) {
        return _excludedFromFee[account];
    }

    function excludeFromFee(address account) external onlyOwner {
        _excludedFromFee[account] = true;
    }
    
    function includeInFee(address account) external onlyOwner {
        _excludedFromFee[account] = false;
    }

    function isVIPWallet(address account) external view returns(bool) {
        return _VIPWallet[account];
    }

    function excludeFromVIP(address account) external onlyOwner {
        _VIPWallet[account] = false;
    }
    
    function includeInVIP(address account) external onlyOwner {
        _VIPWallet[account] = true;
    }

    function checkBlacklist(address account) external view returns (bool) {
        return _blacklist[account];
    }

    function addToBlacklist(address account) external onlyOwner {
        _blacklist[account] = true;
    }
    
    function removeFromBlacklist(address account) external onlyOwner {
        _blacklist[account] = false;
    }
    
    /** 
    * @dev Set fees of CharityCommunity, Operations, LP when buying
    *
    * @param charityCommunityFee: CharityCommunity fee. ex: `1`. 
    * @param operationsFee: Operations fee. ex: `5`.
    * @param lpFee: Liquidity Pool fee. ex: `2`.
    */
    function setBuyFeesPercent(uint8 charityCommunityFee, uint8 operationsFee, uint8 lpFee) external onlyOwner {
        buyCharityCommunityFee = charityCommunityFee;
        buyOperationsFee = operationsFee;
        buyLPFee = lpFee;
        buyTeamFees = buyCharityCommunityFee + buyOperationsFee + buyLPFee;
    }

    /** 
    * @dev Set fees of CharityCommunity, Operations, LP when selling
    *
    * @param charityCommunityFee: CharityCommunity fee. ex: `1`. 
    * @param operationsFee: Operations fee. ex: `5`.
    * @param lpFee: Liquidity Pool fee. ex: `2`.
    */
    function setSellFeesPercent(uint8 charityCommunityFee, uint8 operationsFee, uint8 lpFee) external onlyOwner {
        sellCharityCommunityFee = charityCommunityFee;
        sellOperationsFee = operationsFee;
        sellLPFee = lpFee;
        sellTeamFees = sellCharityCommunityFee + sellOperationsFee + sellLPFee;
    }

    /** 
    * @dev Set antibot fees of CharityCommunity, Operations, LP when selling
    *
    * @param charityCommunityFee: CharityCommunity fee. ex: `8`. 
    * @param operationsFee: Operations fee. ex: `20`.
    * @param lpFee: Liquidity Pool fee. ex: `2`.
    */
    function setSellFeesPercentForAntibot(uint8 charityCommunityFee, uint8 operationsFee, uint8 lpFee) external onlyOwner {
        sellCharityCommunityFeeForAntibot = charityCommunityFee;
        sellOperationsFeeForAntibot = operationsFee;
        sellLPFeeForAntibot = lpFee;
        sellTeamFeesForAntibot = sellCharityCommunityFeeForAntibot + sellOperationsFeeForAntibot + sellLPFeeForAntibot;
    }

    /** 
    * @dev Set fees of CharityCommunity, Operations, LP when transfering
    *
    * @param charityCommunityFee: CharityCommunity fee. ex: `1`. 
    * @param operationsFee: Operations fee. ex: `5`.
    * @param lpFee: Liquidity Pool fee. ex: `2`.
    */
    function setTransferFeesPercent(uint8 charityCommunityFee, uint8 operationsFee, uint8 lpFee) external onlyOwner {
        transferCharityCommunityFee = charityCommunityFee;
        transferOperationsFee = operationsFee;
        transferLPFee = lpFee;
        transferTeamFees = transferCharityCommunityFee + transferOperationsFee + transferLPFee;
    }

    /** 
    * @dev Set fees of CharityCommunity, Operations, LP for VIP when transfering
    *
    * @param charityCommunityFee: CharityCommunity fee. ex: `1`. 
    * @param operationsFee: Operations fee. ex: `5`.
    * @param lpFee: Liquidity Pool fee. ex: `2`.
    */
    function setTransferFeesPercentForVIP(uint8 charityCommunityFee, uint8 operationsFee, uint8 lpFee) external onlyOwner {
        transferCharityCommunityFeeForVIP = charityCommunityFee;
        transferOperationsFeeForVIP = operationsFee;
        transferLPFeeForVIP = lpFee;
        transferTeamFeesForVIP = transferCharityCommunityFeeForVIP + transferOperationsFeeForVIP + transferLPFeeForVIP;
    }

    /**
    * @param maxTxPercent: Max transaction percentage. ex: `2`.
    */
    function setMaxTxPercent(uint8 maxTxPercent) external onlyOwner {
        require(maxTxPercent < 100, "ERROR: Should be less than 100.");
        maxTxAmount = _totalSupply.mul(maxTxPercent).div(100);
    }
    
    /**
    * @param maxTxExact: Max transaction amounts. ex: `100000000`.
    * R3JhbnQgaXMgYSBseWluZyBkb3VjaGViYWcu
    */
    function setMaxTxExact(uint256 maxTxExact) external onlyOwner {
        maxTxAmount = maxTxExact;
    }

    /**
    * @param minAmountToSwapExact: Min amounts to swap. ex: `100000000`.
    */
    function setMinAmountToSwap(uint256 minAmountToSwapExact) external onlyOwner {
        minAmountToSwap = minAmountToSwapExact;
    }
    
    function setCharityCommunityAddress(address account) external onlyOwner {
        require(charityCommunityAddress != account, "ERROR: Can not set to same address.");
        charityCommunityAddress = payable(account);
    }
    
    function setOperationsAddress(address account) external onlyOwner {
        require(operationsAddress != account, "ERROR: Can not set to same address.");
        operationsAddress = payable(account);
    }
    
    function setAutoSwapEnabled(bool status) external onlyOwner {
        isAutoSwapEnabledForTeam = status;

        emit SetAutoSwapEnabled(status);
    }
    
    function setAutoSwapEnabledForStableToken(bool status) external onlyOwner {
        isAutoSwapEnabledForVIP = status;

        emit SetAutoSwapEnabledForVIP(status);
    }
    
    function setStableTokenAddress(address account) external onlyOwner {
        require(stableTokenAddress != account, "ERROR: Can not set to same address.");
        stableTokenAddress = account;
    }

    function setAntibotEnabled(bool status) external onlyOwner {
        isAntibotEnabled = status;
    }
    
    // Get Buy time
    function getBuyTime(address account) external view returns (uint256) {
        return _holderFirstBuyTimestamp[account];
    }

    // Set Antibot Fee Time
    function setAntibotFeeTime(uint256 time) external onlyOwner {
        _antibotFeeTime = time;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(!_blacklist[from] && !_blacklist[to], "Your account is blacklisted.");

        if (from != owner() && to != owner()) {
            require(amount <= maxTxAmount, "Transfer amount exceeds the maxTxAmount.");

            if (!isTradingEnabled) {
                require(preTrader[from], "Trading is not enabled.");
            }
        }

        uint256 contractTokenBalance = balanceOf(address(this));
        bool canSwap = contractTokenBalance >= minAmountToSwap;

        if (canSwap && isAutoSwapEnabledForTeam &&
            !_isSwapping && from != uniswapV2Pair &&
            to != uniswapV2Pair && !_VIPWallet[to]) {
            _swapAndSend(contractTokenBalance);
        }

        bool takeFee = true;
        
        //if any account belongs to _isExcludedFromFee account then remove the fee
        if (_excludedFromFee[from] || _excludedFromFee[to]) {
            takeFee = false;
        }

        uint256 tokensForTeam = 0;
        if (takeFee) {
            // on buy
            if (from == uniswapV2Pair) {
                _holderFirstBuyTimestamp[to] = block.timestamp;

                if (buyTeamFees > 0) {
                    tokensForTeam = amount.mul(buyTeamFees).div(100);
                    getTokensForFee(amount, buyCharityCommunityFee, buyOperationsFee, buyLPFee);
                }
            }
            // on sell
            else if (to == uniswapV2Pair) {
                if (isAntibotEnabled &&
                    sellTeamFeesForAntibot > 0 &&
                    !excludedFromAntibot[from] &&
                    _holderFirstBuyTimestamp[from] != 0 &&
                    (_holderFirstBuyTimestamp[from] + _antibotFeeTime >= block.timestamp)
                ) {
                    tokensForTeam = amount.mul(sellTeamFeesForAntibot).div(100);
                    getTokensForFee(amount, sellCharityCommunityFeeForAntibot, sellOperationsFeeForAntibot, sellLPFeeForAntibot);
                } else if (sellTeamFees > 0) {
                    tokensForTeam = amount.mul(sellTeamFees).div(100);
                    getTokensForFee(amount, sellCharityCommunityFee, sellOperationsFee, sellLPFee);
                }
            }
            // on transfer
            else if (from != uniswapV2Pair && to != uniswapV2Pair) {
                if (_VIPWallet[to]) {
                    if (transferTeamFeesForVIP > 0) {
                        tokensForTeam = amount.mul(transferTeamFeesForVIP).div(100);
                        getTokensForFee(amount, transferCharityCommunityFeeForVIP, transferOperationsFeeForVIP, transferLPFeeForVIP);
                    }

                    if (isAutoSwapEnabledForVIP) {
                        if (tokensForTeam > 0) {
                            amount -= tokensForTeam;
                            super._transfer(from, address(this), tokensForTeam);
                        }

                        super._transfer(from, address(this), amount);
                        uint256 stableToken = _swapTokensFor(amount, stableTokenAddress);
                        _transferStableTokensToWallets(payable(to), stableToken);

                        return;
                    }
                } else if (transferTeamFees > 0) {
                    tokensForTeam = amount.mul(transferTeamFees).div(100);
                    getTokensForFee(amount, transferCharityCommunityFee, transferOperationsFee, transferLPFee);
                }
            }

            if (tokensForTeam > 0) {
        	    amount -= tokensForTeam;
                super._transfer(from, address(this), tokensForTeam);
            }
        }

        super._transfer(from, to, amount);
    }

    function getTokensForFee(uint256 amount, uint256 charityCommunityFee, uint256 operationsFee, uint256 LPFee) private {
        tokensForCharityCommunity += amount.mul(charityCommunityFee).div(100);
        tokensForOperations += amount.mul(operationsFee).div(100);
        tokensForLP += amount.mul(LPFee).div(100);
    }
    
    /** 
    * @dev Swap for WMATIC.
    *
    * @param tokenAmount: Token amounts to be swapped.
    */
    function _swapTokensForWETH(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    /** 
    * @dev Swap Token -> WMATIC -> StableToken.
    *
    * @param tokenAmount: Token amounts to be swapped.
    */
    function _swapTokensForStableToken(uint256 tokenAmount) private {
        address[] memory path = new address[](3);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        path[2] = stableTokenAddress;

        _approve(address(this), address(uniswapV2Router), tokenAmount);

         // make the swap
        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function _swapTokensFor(uint256 amounts, address tokenDesiredToSwap ) private returns (uint256) {
        IERC20 stableToken = IERC20(stableTokenAddress);
        uint256 tokensSwapped = 0;

        if (tokenDesiredToSwap == stableTokenAddress) {
            uint256 initialStableTokenBalance = stableToken.balanceOf(address(this));
            _swapTokensForStableToken(amounts);
            tokensSwapped = stableToken.balanceOf(address(this)).sub(initialStableTokenBalance);
        } else {
            uint256 initialETHBalance = address(this).balance;
            _swapTokensForWETH(amounts);
            tokensSwapped = address(this).balance.sub(initialETHBalance);
        }

        return tokensSwapped;
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    function _swapAndSend(uint256 contractTokenBalance) private lockSwap {
        uint256 totalTokens = tokensForCharityCommunity.add(tokensForOperations).add(tokensForLP);

        uint256 tokenBalanceForLP = contractTokenBalance.mul(tokensForLP).div(totalTokens);

        uint256 halfTokensForLP = tokenBalanceForLP.div(2);
        uint256 tokensToSwap = contractTokenBalance.sub(halfTokensForLP);

        uint256 maticBalance = _swapTokensFor(tokensToSwap, uniswapV2Router.WETH());

        uint256 maticForCharityCommunity = maticBalance.mul(tokensForCharityCommunity).div(totalTokens);
        uint256 maticForOperations = maticBalance.mul(tokensForOperations).div(totalTokens);
        uint256 maticForLP = maticBalance.sub(maticForCharityCommunity).sub(maticForOperations);

        charityCommunityAddress.transfer(maticForCharityCommunity);

        // add liquidity
        if (halfTokensForLP > 0 && maticForLP > 0) {
            addLiquidity(halfTokensForLP, maticForLP);

            emit AddLiquidity(halfTokensForLP, maticForLP);
        }

        operationsAddress.transfer(address(this).balance);

        tokensForCharityCommunity = 0;
        tokensForOperations = 0;
        tokensForLP = 0;
    }

    function manualSwapForTeam() external onlyOwner {
        uint256 contractTokenBalance = balanceOf(address(this));
        _swapAndSend(contractTokenBalance);
    }

    /** 
    * @dev Send to recipient the converted stable token.
    *
    * @param recipient: Address to receive.
    * @param amount: Token amounts to transfer.
    */
    function _transferStableTokensToWallets(address payable recipient, uint256 amount) private {
        IERC20 stableToken = IERC20(stableTokenAddress);
        stableToken.transfer(recipient, amount);

        emit Transfer(address(this), recipient, amount);
    }
}