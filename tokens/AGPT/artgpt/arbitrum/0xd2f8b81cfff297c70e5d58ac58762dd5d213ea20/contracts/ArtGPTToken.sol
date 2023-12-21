// SPDX-License-Identifier: GPL3.0
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IUniswapFactory.sol";
import "./interfaces/IUniswapV2Router02.sol";

contract ArtGPTToken is ERC20, Ownable {
    uint256 public constant supply = 1e9 * 1e18;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;
    address public marketingWallet;
    uint256 public buyTaxRate = 3; // 3% tax buy
    uint256 public sellTaxRate = 9; // 9% tax sell
    bool inSwap = false;

    mapping(address => bool) private isExcludedFromFee;

    uint256 public fightingBotActive = 30000000 * 1e18;
    uint256 public minSwapAmount = 1000000 * 1e18;

    uint256 public fightingBotDuration = 20; //seconds
    uint256 public fightingBot;

    constructor(
        string memory name,
        string memory symbol,
        address _router
    ) ERC20(name, symbol) {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(_router);
        uniswapV2Pair = IUniswapFactory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;

        _mint(_msgSender(), supply);
        isExcludedFromFee[_msgSender()] = true;
        marketingWallet = _msgSender();
    }

    modifier onlyMarketingWallet() {
        require(_msgSender() == marketingWallet, "Only Marketing Wallet!");
        _;
    }

    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }

    function burn(uint256 amount) public {
        _burn(_msgSender(), amount);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        uint256 transferTaxRate = (recipient == uniswapV2Pair &&
            !isExcludedFromFee[sender])
            ? sellTaxRate
            : sender == uniswapV2Pair
            ? buyTaxRate
            : 0;
        if (
            fightingBot > block.timestamp &&
            amount > fightingBotActive &&
            sender != address(this) &&
            recipient != address(this) &&
            sender == uniswapV2Pair
        ) {
            transferTaxRate = 75;
        }

        if (fightingBot == 0 && transferTaxRate > 0 && amount > 0) {
            fightingBot = block.timestamp + fightingBotDuration;
        }

        if (inSwap) {
            super._transfer(sender, recipient, amount);
            return;
        }

        if (
            transferTaxRate > 0 &&
            sender != address(this) &&
            recipient != address(this)
        ) {
            uint256 _tax = (amount * transferTaxRate) / 100;
            super._transfer(sender, address(this), _tax);
            amount = amount - _tax;
        } else {
            callToMarketingWallet();
        }

        super._transfer(sender, recipient, amount);
    }

    function callToMarketingWallet() internal swapping {
        uint256 balanceThis = balanceOf(address(this));

        if (balanceThis > minSwapAmount) {
            swapTokensForETH(minSwapAmount);
        }
    }

    function swapTokensForETH(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.swapExactTokensForETH(
            tokenAmount,
            0,
            path,
            marketingWallet,
            block.timestamp
        );
    }

    function setExcludedFromFee(address _excludedFromFee) public onlyOwner {
        isExcludedFromFee[_excludedFromFee] = true;
    }

    function removeExcludedFromFee(address _excludedFromFee) public onlyOwner {
        isExcludedFromFee[_excludedFromFee] = false;
    }

    function changeMarketingWallet(address _marketingWallet)
        external
        onlyMarketingWallet
    {
        require(_marketingWallet != address(0), "0x is not accepted here");

        marketingWallet = _marketingWallet;
    }

    function changeBuyTaxRate(uint256 _buyTaxRate) external onlyMarketingWallet {
        require(_buyTaxRate < 15, "Invalid rate");
        buyTaxRate = _buyTaxRate;
    }

    function changeSellTaxRate(uint256 _sellTaxRate) external onlyMarketingWallet {
        require(_sellTaxRate < 15, "Invalid rate");
        sellTaxRate = _sellTaxRate;
    }

    function removeOtherERC20Tokens(address _tokenAddress, address _to)
        external
        onlyMarketingWallet
    {
        ERC20 erc20Token = ERC20(_tokenAddress);
        require(
            erc20Token.transfer(_to, erc20Token.balanceOf(address(this))),
            "ERC20 Token transfer failed"
        );
    }
}
