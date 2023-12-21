// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IUniswapInterface.sol";

/// @custom:security-contact security@arreta.org
contract DaoSpace is Initializable, ERC20Upgradeable, ERC20PermitUpgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    address public marketingWallet;
    uint public maxTransactionAmount;
    uint public maxWalletAmount;
    uint public swapTokensAtAmount;

    // Fees
    uint public buyFee;
    uint public sellFee;
    uint public transferFee;

    bool public tradingActive;
    bool public swapEnabled;
    bool private swapping;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    //Exlcude from fees and max transaction amount
    mapping(address => bool) public isExcludedFromFees;
    mapping(address => bool) public isExcludedMaxTransactionAmount;
    mapping(address => bool) public isExcludedMaxWallet;

    mapping(address => bool) public automatedMarketMakerPairs;

    // Events
    event MigrateTokens(address indexed from, uint256 amount);
    event ExcludeFromFees(address indexed account, bool isExcluded);
    event ExcludeFromMaxTransactionAmount(address indexed account, bool isExcluded);
    event ExcludeFromMaxWallet(address indexed account, bool isExcluded);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    event marketingWalletUpdated(address indexed newWallet, address indexed oldWallet);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() initializer public {
        __ERC20_init("DaoSpace", "DAOP");
        __ERC20Permit_init("DaoSpace");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        _mint(msg.sender, 100_000_000 * 10 ** decimals());

        // 0xD99D1c33F9fC3444f8101754aBC46c52416550D1 testnet
        uniswapV2Router = IUniswapV2Router02(address(0x10ED43C718714eb63d5aA57B78B54704E256024E));
        // uniswapV2Router = IUniswapV2Router02(address(0xD99D1c33F9fC3444f8101754aBC46c52416550D1));
        // uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());

        // 0.5% MaxTx amount
        maxTransactionAmount = (totalSupply() * 5) / 1000;
        // 1.0% Max Wallet Size
        maxWalletAmount = (totalSupply() * 10) / 1000;
        // 0.01% TrashHold
        swapTokensAtAmount = (totalSupply() * 1) / 10000;

        // 50 = 5% Buy Fee
        buyFee = 0;
        // 100 = 10% Sell Fee
        sellFee = 100;
        // 0 = 0% Transfer Fee
        transferFee = 0;

        // 0xf8d572Ff05d6414585cF4B938785D52f0CdD0948 testnet
        marketingWallet = address(0xF90E8785FbB93Ed677C4f8d3dD35385290902c3D);
        // marketingWallet = address(0xf8d572Ff05d6414585cF4B938785D52f0CdD0948);

        _excludeFromFees(address(this), true);
        _excludeFromFees(msg.sender, true);
        _excludeFromFees(marketingWallet, true);

        _excludeFromMaxTransaction(address(this), true);
        _excludeFromMaxTransaction(msg.sender, true);
        _excludeFromMaxTransaction(marketingWallet, true);

        _excludeFromMaxWallet(address(this), true);
        _excludeFromMaxWallet(msg.sender, true);
        _excludeFromMaxWallet(marketingWallet, true);
    }

    function _authorizeUpgrade(address newImplementation) internal onlyRole(UPGRADER_ROLE) override {}

    function _beforeTokenTransfer(address from, address to, uint amount) internal override(ERC20Upgradeable) {
        super._beforeTokenTransfer(from, to, amount);
    }

    receive() external payable {}

    function migrateTokens() external {
        // 0xADaEeCd845fEEC101069eDBBFbf7EF87a99716dE testnet
        ERC20Upgradeable _v1 = ERC20Upgradeable(0xdA179357B3E05CD91e0fde992c7eF4158b37EaFb);
        // ERC20Upgradeable _v1 = ERC20Upgradeable(0xADaEeCd845fEEC101069eDBBFbf7EF87a99716dE);
        uint _amount = _v1.balanceOf(msg.sender);

        require(_amount > 0, "No tokens to migrate");

        // Transfer V1 tokens from sender to this contract
        require(_v1.transferFrom(msg.sender, marketingWallet, _amount), "V1 token transfer failed");

        // Transfer V2 tokens from this contract to sender
        // 0xF90E8785FbB93Ed677C4f8d3dD35385290902c3D marketing
        // _transfer(address(this), msg.sender, _amount);
        _transfer(marketingWallet, msg.sender, _amount);

        emit MigrateTokens(msg.sender, _amount);
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(to != address(0xdead), "ERC20: transfer to the dead address");
        require(amount > 0, "Transfer amount must be greater than zero");

        _checkLimits(from, to, amount);

        uint256 contractTokenBalance = balanceOf(address(this));
        bool canSwap = contractTokenBalance >= swapTokensAtAmount;

        if (canSwap && swapEnabled && !swapping && !automatedMarketMakerPairs[from] && !isExcludedFromFees[from] && !isExcludedFromFees[to]) {
            swapping = true;
            swapBack();
            swapping = false;
        }

        bool takeFee = !swapping;

        //if the account belongs to _isExcludedFromFee then remove the fee
        if (isExcludedFromFees[from] || isExcludedFromFees[to]) {
            takeFee = false;
        }

        uint256 fees = 0;
        //Take fees on buys/sells, do not work on wallet transfers
        if (takeFee) {
            //Sell
            if (automatedMarketMakerPairs[to] && sellFee > 0) {
                if (balanceOf(from) == amount) amount--; //Keep 1 token in wallet to keep holders incremental
                fees = amount * sellFee / 1000;
            }
            //Buy
            else if (automatedMarketMakerPairs[from] && buyFee > 0) {
                fees = amount * buyFee / 1000;
            }
            // Transfer
            else if (transferFee > 0) {
                fees = amount * transferFee / 1000;
            }

            amount -= fees;

            if (fees > 0) {
                super._transfer(from, address(this), fees);
            }
        }

        super._transfer(from, to, amount);
    }

    function _checkLimits(address _from, address _to, uint256 _amount) private view {
        if (!hasRole(DEFAULT_ADMIN_ROLE, _from) && !hasRole(DEFAULT_ADMIN_ROLE, _to) && !swapping) {
            if (!tradingActive) {
                if (_from != address(this) || _to != address(this)) {
                    require(isExcludedFromFees[_from] || isExcludedFromFees[_to], "Trading is not active.");
                }
            }

            //when buy
            if (automatedMarketMakerPairs[_from] && !isExcludedMaxTransactionAmount[_to]) {
                require(_amount <= maxTransactionAmount, "Buy transfer amount exceeds.");
                if (!isExcludedMaxWallet[_from] && !isExcludedMaxWallet[_to]) {
                    require(_amount + balanceOf(_to) <= maxWalletAmount, "Max wallet exceeded.");
                }
            }
            //when sell
            else if (automatedMarketMakerPairs[_to] && !isExcludedMaxTransactionAmount[_from]) {
                require(_amount <= maxTransactionAmount, "Sell transfer amount exceeds.");
            } else {
                if (!isExcludedMaxWallet[_from] && !isExcludedMaxWallet[_to]) {
                    require(_amount + balanceOf(_to) <= maxWalletAmount, "Max wallet exceeded.");
                }
            }
        }
    }

    function swapBack() private {
        uint256 contractBalance = balanceOf(address(this));

        if (contractBalance == 0) {
            return;
        }

        //Prevent large dumps.
        if (contractBalance > swapTokensAtAmount * 3) {
            contractBalance = swapTokensAtAmount * 3;
        }

        swapTokensForEth(contractBalance);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(marketingWallet),
            block.timestamp
        );
    }

    /// Admin Functions

    //Once enabled, can never be used
    function enableTrading() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(tradingActive == false);

        tradingActive = true;
        swapEnabled = true;
    }

    // %1 = 10
    function setFees(uint256 _buy, uint256 _sell, uint256 _transferFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        buyFee = _buy;
        sellFee = _sell;
        transferFee = _transferFee;
    }

    // set Max Wallet Percent %1 = 10
    function setMaxWallet(uint256 _maxWallet) external onlyRole(DEFAULT_ADMIN_ROLE) {
        maxWalletAmount = (totalSupply() * _maxWallet) / 1000;
    }

    // set Max Transaction Percent %0.5 = 5
    function setMaxTransaction(uint256 _maxTx) external onlyRole(DEFAULT_ADMIN_ROLE) {
        maxTransactionAmount = (totalSupply() * _maxTx) / 1000;
    }

    // set Swap Tokens At Amount Percent %0.03 = 3
    function setSwapTokensAtAmount(uint256 _percent) external onlyRole(DEFAULT_ADMIN_ROLE) {
        swapTokensAtAmount = (totalSupply() * _percent) / 10000;
    }

    function setMarketingWallet(address _marketingWallet) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_marketingWallet != address(0), "Marketing wallet cannot be 0x0");
        
        marketingWallet = _marketingWallet;

        emit marketingWalletUpdated(_marketingWallet, marketingWallet);
    }

    function excludeFromFees(address account, bool excluded) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _excludeFromFees(account, excluded);
    }

    function excludeFromMaxTransaction(address account, bool excluded) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _excludeFromMaxTransaction(account, excluded);
    }

    function excludeFromMaxWallet(address account, bool excluded) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _excludeFromMaxWallet(account, excluded);
    }

    function setAutomatedMarketMakerPair(address pair, bool value) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // require(pair != uniswapV2Pair, "The PancakeSwap pair cannot be removed from automatedMarketMakerPairs");

        _setAutomatedMarketMakerPair(pair, value);
    }

    function setUniswapPair(address _uniswapV2Pair) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uniswapV2Pair = _uniswapV2Pair;
    }

    /// Private Functions

    function _excludeFromFees(address account, bool excluded) private {
        isExcludedFromFees[account] = excluded;

        emit ExcludeFromFees(account, excluded);
    }

    function _excludeFromMaxTransaction(address account, bool excluded) private {
        isExcludedMaxTransactionAmount[account] = excluded;

        emit ExcludeFromMaxTransactionAmount(account, excluded);
    }

    function _excludeFromMaxWallet(address account, bool excluded) private {
        isExcludedMaxWallet[account] = excluded;

        emit ExcludeFromMaxWallet(account, excluded);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        automatedMarketMakerPairs[pair] = value;

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    // Current Version of the implementation
    function version() external pure virtual returns (string memory) {
        return '2.0.0';
    }
}
