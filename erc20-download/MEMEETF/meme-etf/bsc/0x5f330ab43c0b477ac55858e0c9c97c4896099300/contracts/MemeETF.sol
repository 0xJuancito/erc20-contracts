// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

error OPEN_SWAP();
error ZERO_ADDRESS();

contract MemeETF is Context, ERC20Burnable, Ownable {
    using Address for address payable;
    using SafeERC20 for IERC20;

    bool public taxEnabled;
    address payable public marketingWallet;
    address payable public eTFWallet;
    address public immutable dexPair;
    bool inSwap;

    IUniswapV2Router02 public dexRouter;

    //fees 100 = 1%
    uint256 public marketingTax;
    uint256 public eTFTax;
    uint256 _marketingTax;
    uint256 _eTFTax;
    uint256 constant FEE_DENOMINATOR = 1e4;
    uint256 constant TAX_LIMIT = 400;

    mapping(address => bool) _isExcluded;

    event SetTaxStatus(bool indexed enable);
    event SwapAndPay(uint256 swappedETH, uint256 mTax, uint256 eTax);
    event TaxSet(uint256 marketingTax_, uint256 eTFTax_);
    event Excluded(address indexed account, bool indexed exclude);
    event WalletSet(address indexed marketingWallet, address indexed eTFWallet);

    modifier lockSwap() {
        _lockSwap();
        _;
        inSwap = false;
    }

    constructor(
        uint256 marketingTax_,
        uint256 eTFTax_,
        address _owner,
        address payable marketingWallet_,
        address payable eTFWallet_,
        address dexRouter_
    ) ERC20("Meme ETF", "MemeETF") Ownable(_owner) {
        marketingWallet = marketingWallet_;
        eTFWallet = eTFWallet_;

        eTFTax = eTFTax_;
        marketingTax = marketingTax_;

        dexRouter = IUniswapV2Router02(dexRouter_);

        // Create a uniswap pair for this new token
        dexPair = IUniswapV2Factory(dexRouter.factory()).createPair(
            address(this),
            dexRouter.WETH()
        );

        //exclude owner and this contract from fee
        _isExcluded[address(this)] = true;
        _isExcluded[dexRouter_] = true;
        _isExcluded[_owner] = true;

        _mint(_owner, 13e30); //13 trillion total supply
    }

    receive() external payable {}

    function calculateTxFee(
        address from,
        address to,
        uint256 amount
    ) public view returns (uint256 marketingTax_, uint256 eTFTax_) {
        // deducts `marketingTax` and `eTFTax` from `amount`
        if (!taxEnabled) return (0, 0);

        bool excluded = _isExcluded[from] || _isExcluded[to];

        if (excluded) {
            (marketingTax_, eTFTax_) = (0, 0);
        } else {
            uint256 denom_ = FEE_DENOMINATOR;
            unchecked {
                marketingTax_ = (amount * marketingTax) / denom_;
                eTFTax_ = (amount * eTFTax) / denom_;
            }
        }
    }

    function isExcludedFromTax(address account) external view returns (bool) {
        return _isExcluded[account];
    }

    function setWallets(
        address payable marketingWallet_,
        address payable eTFWallet_
    ) external onlyOwner {
        if (marketingWallet_ == address(0) || eTFWallet_ == address(0))
            revert ZERO_ADDRESS();
        marketingWallet = marketingWallet_;
        eTFWallet = eTFWallet_;
        emit WalletSet(marketingWallet_, eTFWallet_);
    }

    function setExcludeFromTax(
        address[] memory accounts,
        bool exclude
    ) external onlyOwner {
        uint256 len = accounts.length;
        address account;
        for (uint256 i; i < len; ) {
            account = accounts[i];
            _isExcluded[account] = exclude;
            emit Excluded(account, exclude);
            unchecked {
                ++i;
            }
        }
    }

    function setTax(uint256 marketingTax_, uint256 eTFTax_) external onlyOwner {
        uint limit = TAX_LIMIT;
        require(
            marketingTax_ <= limit && eTFTax_ <= limit,
            "TAX_LIMIT exceeded"
        );
        eTFTax = eTFTax_;
        marketingTax = marketingTax_;
        emit TaxSet(marketingTax_, eTFTax_);
    }

    function toggleTaxEnable() external onlyOwner {
        bool status = taxEnabled;
        taxEnabled = status ? false : true;
        emit SetTaxStatus(!status);
    }

    function totalTaxed()
        public
        view
        returns (uint256 totalMarketingTaxed, uint256 totalETFTaxed)
    {
        return (_marketingTax, _eTFTax);
    }

    function transfer(
        address to,
        uint256 amount
    ) public override(ERC20) returns (bool) {
        __transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override(ERC20) returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        __transfer(from, to, amount);
        return true;
    }

    function __transfer(address from, address to, uint256 amount) private {
        (uint256 marketingTax_, uint256 eTFTax_) = calculateTxFee(
            from,
            to,
            amount
        );

        uint256 totalFee = marketingTax_ + eTFTax_;

        if (totalFee > 0) {
            uint256 totalSend = amount - totalFee;

            if (dexPair == from) {
                _transfer(from, address(this), totalFee);
                _transfer(from, to, totalSend);
            } else {
                _transfer(from, address(this), totalFee);
                uint256 caBalances = balanceOf(address(this));
                if (caBalances > 0) {
                    _swapAndPay(caBalances);
                }
                _transfer(from, to, totalSend);
            }
        } else {
            _transfer(from, to, amount);
        }
    }

    function _lockSwap() private {
        if (inSwap) revert OPEN_SWAP();
        inSwap = true;
    }

    function _swapAndPay(uint256 tokensToSwap) private lockSwap {
        uint256 initialBal = address(this).balance;
        _swapTokensForEth(tokensToSwap);
        uint256 bal = address(this).balance - initialBal;
        (uint256 mTax, uint256 eTax) = _calculateSplit(bal);

        unchecked {
            _marketingTax += mTax;
            _eTFTax += eTax;
        }

        marketingWallet.sendValue(mTax);
        eTFWallet.sendValue(eTax);
        emit SwapAndPay(bal, mTax, eTax);
    }

    function _swapTokensForEth(uint256 amount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = dexRouter.WETH();

        _approve(address(this), address(dexRouter), amount);

        dexRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function _calculateSplit(
        uint256 amount
    ) private view returns (uint256 mTax, uint256 eTax) {
        uint256 mTaxRate = marketingTax;
        uint256 total = mTaxRate + eTFTax;

        unchecked {
            mTax = (amount * mTaxRate) / total;
            eTax = amount - mTax;
        }
    }
}
