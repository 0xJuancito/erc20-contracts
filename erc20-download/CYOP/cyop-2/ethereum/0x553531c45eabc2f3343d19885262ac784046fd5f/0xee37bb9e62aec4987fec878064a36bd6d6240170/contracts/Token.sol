// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "./ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./interfaces/IDEXFactory.sol";
import "./interfaces/IDEXRouter.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract CyOp is Initializable, ERC20Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    using SafeMathUpgradeable for uint256;
    mapping (address => bool) public isExcludedFromFee;
    
    address payable public treasury1Wallet;
    address payable public treasury2Wallet;
    uint256 public treasury1Split;
    uint256 public treasury2Split;

    uint256 public feePermille;
    uint256 public discountedFeePermille;

    uint256 public collectedTaxThreshold;

    address public uniswapV2Pair;
    bool public tradingOpen;
    bool public autoTaxDistributionEnabled;
    bool private inInternalSwap;
    IDEXRouter public uniswapV2Router;
    IERC721 public uNFT;

    event ConfigurationChange(string varName, uint256 value);
    event ConfigurationChange(string varName, address value);
    event ConfigurationChange(string varName, bool value);
    event ConfigurationChange(string varName, address key, bool value);
    event ConfigurationChange(string funcName);

    modifier lockTheSwap {
        inInternalSwap = true;
        _;
        inInternalSwap = false;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address payable _treasury1Wallet, 
                        address payable _treasury2Wallet, 
                        uint256 _treasury1Split, 
                        uint256 _treasury2Split, 
                        uint256 _feePermille, 
                        uint256 _discountedFeePermille, 
                        IERC721 _uNFT, 
                        IDEXRouter _uniswapV2Router) initializer public {
        __ERC20_init("CyOp", "CyOp");
        __Ownable_init();
        __UUPSUpgradeable_init();

        treasury1Wallet = _treasury1Wallet;
        treasury2Wallet = _treasury2Wallet;
        treasury1Split = _treasury1Split;
        treasury2Split = _treasury2Split;
        feePermille = _feePermille;
        discountedFeePermille = _discountedFeePermille;

        uNFT = _uNFT;
        uniswapV2Router = _uniswapV2Router;

        isExcludedFromFee[owner()] = true;
        isExcludedFromFee[address(this)] = true;
        isExcludedFromFee[_treasury1Wallet] = true;
        isExcludedFromFee[_treasury2Wallet] = true;

        _mint(msg.sender, 100_000_000 * 10 ** decimals());
        collectedTaxThreshold = _totalSupply / 1000; // 0.1% of total supply  
    }

    function _transfer(address from, address to, uint256 amount) internal override(ERC20Upgradeable) {
        require(from != address(0), "ERC20: transfer from invalid");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        uint256 taxAmount = 0;
        if (!isExcludedFromFee[from] && !isExcludedFromFee[to]) {
            require(tradingOpen, "Trading is not open yet");
            bool _isTransfer = from != uniswapV2Pair && to != uniswapV2Pair;
            
            if (!inInternalSwap && !_isTransfer) {
                uint256 _collectedTaxThreshold = collectedTaxThreshold;
                uint256 _feePermille = uNFT.balanceOf(from) > 0 || uNFT.balanceOf(to) > 0 ? discountedFeePermille : feePermille;
                taxAmount = amount.mul(_feePermille).div(1000);
                if (from != uniswapV2Pair && autoTaxDistributionEnabled && balanceOf(address(this)) > _collectedTaxThreshold) {
                    _distributeTaxes(_collectedTaxThreshold);
                }
            }
        }

        _balances[from]=_balances[from].sub(amount);
        _balances[to]=_balances[to].add(amount.sub(taxAmount));

        emit Transfer(from, to, amount.sub(taxAmount));

        if (taxAmount > 0) {
          _balances[address(this)]=_balances[address(this)].add(taxAmount);
          emit Transfer(from, address(this), taxAmount);
        }
    }

    function _swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function enableTrading() external onlyOwner {
        require(!tradingOpen, "Trading is already open");
        uniswapV2Pair = IDEXFactory(uniswapV2Router.factory()).getPair(address(this), uniswapV2Router.WETH());
        autoTaxDistributionEnabled = true;
        tradingOpen = true;
        emit ConfigurationChange("TradingEnabled");
    }

    function setAutoTaxDistributionEnabled(bool _enabled) external onlyOwner {
        autoTaxDistributionEnabled = _enabled;
        emit ConfigurationChange("autoTaxDistributionEnabled", _enabled);
    }

    function setFees(uint256 _feePermille, uint256 _discountedFeePermille) external onlyOwner {
        require(_feePermille <= 100 || _feePermille < feePermille, "INVALID_FEE");
        require(_discountedFeePermille <= 100 || _discountedFeePermille < discountedFeePermille, "INVALID_DISCOUNTED_FEE");
        require(_discountedFeePermille <= _feePermille, "INVALID_FEES");
        feePermille = _feePermille;
        discountedFeePermille = _discountedFeePermille;
        emit ConfigurationChange("feePermille", _feePermille);
        emit ConfigurationChange("discountedFeePermille", _discountedFeePermille);
    }

    function setTaxThreshold(uint256 _newThreshold) external onlyOwner {
        collectedTaxThreshold = _newThreshold;
        emit ConfigurationChange("collectedTaxThreshold", _newThreshold);
    }

    function setExcludeFromFee(address _address, bool _excluded) external onlyOwner {
        isExcludedFromFee[_address] = _excluded;
        emit ConfigurationChange("isExcludedFromFee", _address, _excluded);
    }

    function setTreasuryAddress(address payable _treasury1Wallet, address payable _treasury2Wallet) external onlyOwner {
        treasury1Wallet = _treasury1Wallet;
        treasury2Wallet = _treasury2Wallet;
        emit ConfigurationChange("treasury1Wallet", _treasury1Wallet);
        emit ConfigurationChange("treasury2Wallet", _treasury2Wallet);
    }

    function setUnftAddress(IERC721 _uNFT) external onlyOwner {
        uNFT = _uNFT;
        emit ConfigurationChange("uNFT", address(_uNFT));
    }

    function setSplits(uint256 _treasury1Split, uint256 _treasury2Split) external onlyOwner {
        require(_treasury1Split + _treasury2Split == 100, "INVALID_SPLITS");
        treasury1Split = _treasury1Split;
        treasury2Split = _treasury2Split;
        emit ConfigurationChange("treasury1Split", _treasury1Split);
        emit ConfigurationChange("treasury2Split", _treasury2Split);
    }

    function distributeTaxes(uint256 amount) external onlyOwner {
        _distributeTaxes(amount);
    }

    function _distributeTaxes(uint256 amount) internal { 
        _swapTokensForEth(amount);    
        uint256 contractETHBalance = address(this).balance;

        if (contractETHBalance > 0) {
            uint256 treasury1Amount = contractETHBalance.mul(treasury1Split).div(100);
            uint256 treasury2Amount = contractETHBalance - treasury1Amount;
            _sendViaCall(treasury1Wallet, treasury1Amount);
            _sendViaCall(treasury2Wallet, treasury2Amount);
        }
    }

    function _sendViaCall(address payable _to, uint256 amountETH) internal {
        // Call returns a boolean value indicating success or failure.
        // This is the current recommended method to use.
        if (amountETH == 0) {
            return;
        }
        (bool sent, ) = _to.call{value: amountETH}("");
        require(sent, "Failed to send Ether");
    }

    function withdrawERC20(IERC20Upgradeable token) external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        bool sent = token.transfer(msg.sender, balance);
        require(sent, "Failed to send token");    
    }

    function withdrawETH() external onlyOwner {
        uint256 balance = address(this).balance;
        _sendViaCall(payable(msg.sender), balance);
    }

    function version() external pure returns (string memory) {
        return "1.0.0";
    }

    receive() external payable {}

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}
}