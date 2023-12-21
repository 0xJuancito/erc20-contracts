// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@upgradeable/security/PausableUpgradeable.sol";
import "@upgradeable/access/AccessControlUpgradeable.sol";
import "@upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@v2p/interfaces/IUniswapV2Router02.sol";

import "./UniwarRecoverable.sol";
import "./UniwarConfigurable.sol";


contract UniwarTokenImpl is UniwarRecoverable, UniwarConfigurable, ERC20Upgradeable, ERC20BurnableUpgradeable, PausableUpgradeable, AccessControlUpgradeable, ERC20PermitUpgradeable {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    enum Swap { None, Buy, Sell }

    struct Tax {
        uint256 unibot;
        uint256 liquidity;
        uint256 treasury;
        uint256 burn;
    }

    Tax public tax;

    bool private _inSwapAndLiquify; // Deprecated

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _config) initializer external {
        __UniwarRecoverable_init();
        __UniwarConfigurable_init_unchained(_config);
        __ERC20_init("UNIWAR", "UNIWAR");
        __ERC20Burnable_init();
        __Pausable_init();
        __AccessControl_init();
        __ERC20Permit_init("UNIWAR");

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _mint(msg.sender, 1e24);
    }

    /// @dev Patch for v0.0.2
    function initialize2() reinitializer(2) external {
        delete tax;
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _transfer(address _from, address _to, uint256 _amount) whenNotPaused internal virtual override {
        require(!config.glacialBind(_from), "UniwarToken: from address frozen");
        require(!config.glacialBind(_to), "UniwarToken: to address frozen");

        if (config.highElves(_from) || config.highElves(_to)) {
            super._transfer(_from, _to, _amount);
            return;
        }

        Swap _swap = Swap.None;
        address _pair = config.pair();

        if (_to == _pair) {
            _swap = Swap.Sell;
        } else if (_from == _pair) {
            _swap = Swap.Buy;
        }

        uint256 _unibotTax;
        uint256 _liquidityTax;
        uint256 _treasuryTax;
        uint256 _burnTax;
        uint256 _totalTax;
        uint256 _afterTax = _amount;

        uint8 _phase = config.phase();

        if (_swap == Swap.Buy) {
            (
                uint16 _unibotTaxRate,
                uint16 _liquidityTaxRate,
                uint16 _treasuryTaxRate,
                uint16 _burnTaxRate
            ) = config.buyTaxRates(_phase);

            _unibotTax = _calcTax(_amount, _unibotTaxRate);
            _liquidityTax = _calcTax(_amount, _liquidityTaxRate);
            _treasuryTax = _calcTax(_amount, _treasuryTaxRate);
            _burnTax = _calcTax(_amount, _burnTaxRate);
            _totalTax = _unibotTax + _liquidityTax + _treasuryTax + _burnTax;
            _afterTax = _amount - _totalTax;

            if (_to != config.router() && _to != _pair) {
                (uint16 _txMaxLimit, uint16 _walletMaxLimit) = config.buyLimits(_phase);

                uint256 _txMax;
                uint256 _walletMax;

                if (_txMaxLimit > 0) {
                    _txMax = _calcTax(totalSupply(), _txMaxLimit);
                } else {
                    _txMax = totalSupply();
                }

                if (_walletMaxLimit > 0) {
                    _walletMax = _calcTax(totalSupply(), _walletMaxLimit);
                } else {
                    _walletMax = totalSupply();
                }

                require(_afterTax <= _txMax, "UniwarToken: buy tx max");
                require(balanceOf(_to) + _afterTax <= _walletMax, "UniwarToken: wallet max");
            }

        } else if (_swap == Swap.Sell) {
            (
                uint16 _unibotTaxRate,
                uint16 _liquidityTaxRate,
                uint16 _treasuryTaxRate,
                uint16 _burnTaxRate
            ) = config.sellTaxRates(_phase);

            _unibotTax = _calcTax(_amount, _unibotTaxRate);
            _liquidityTax = _calcTax(_amount, _liquidityTaxRate);
            _treasuryTax = _calcTax(_amount, _treasuryTaxRate);
            _burnTax = _calcTax(_amount, _burnTaxRate);
            _totalTax = _unibotTax + _liquidityTax + _burnTax + _treasuryTax;
            _afterTax = _amount - _totalTax;

            if (_from != config.router() && _from != _pair) {
                (uint16 _txMaxLimit,) = config.sellLimits(_phase);

                uint256 _txMax;

                if (_txMaxLimit > 0) {
                    _txMax = _calcTax(totalSupply(), _txMaxLimit);
                } else {
                    _txMax = totalSupply();
                }

                require(_afterTax <= _txMax, "UniwarToken: sell tx max");
            }
        }

        tax.unibot += _unibotTax;
        tax.liquidity += _liquidityTax;
        tax.treasury += _treasuryTax;
        tax.burn += _burnTax;

        super._transfer(_from, _to, _afterTax);

        if (_totalTax > 0) {
            super._transfer(_from, address(this), _totalTax);
        }

        uint256 _tax = tax.unibot + tax.liquidity + tax.treasury + tax.burn;

        if (_swap == Swap.None && _tax >= _calcTax(totalSupply(), config.swapThreshold())) {
            _swapAndLiquify();
        }
    }

    /// @dev Use if the contract accumulation balance becomes too high and liquify was not triggered
    function recoverRewards(address _to) external onlyOwner {
        delete tax;
        super._transfer(address(this), _to, balanceOf(address(this)));
    }

    function liquify() external onlyOwner {
        _swapAndLiquify();
    }

    function _swapAndLiquify() private {
        uint256 _unibotTax = tax.unibot;
        uint256 _liquidityTax = tax.liquidity;
        uint256 _treasuryTax = tax.treasury;
        uint256 _burnTax = tax.burn;
        delete tax;

        uint256 _taxSum = (_unibotTax + (_liquidityTax / 2)) + _treasuryTax;
        _swapTokensForEth(_taxSum);

        uint256 _balance = address(this).balance;
        uint256 _unibotEth = _balance * _unibotTax / _taxSum;
        uint256 _liquidityEth = (_balance * (_liquidityTax / 2)) / _taxSum;

        if (_burnTax > 0) {
            _burn(address(this), _burnTax);
        }

        if (_unibotEth > 0) {
            _buyUnibot(_unibotEth);
        }

        if (_liquidityEth > 0) {
            _addLiquidity(
                balanceOf(address(this)),
                _liquidityEth
            );
        }

        (bool success,) = payable(config.treasury()).call{value: address(this).balance}("");
        require(success, "UniwarToken: treasury transfer failed");
    }

    function _swapTokensForEth(uint256 _tokenAmount) private {
        IUniswapV2Router02 _router = IUniswapV2Router02(config.router());
        _approve(address(this), address(_router), _tokenAmount);
        address[] memory _path = new address[](2);
        _path[0] = address(this);
        _path[1] = _router.WETH();
        _router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            _tokenAmount,
            0,
            _path,
            address(this),
            block.timestamp
        );
    }

    function _buyUnibot(uint256 _ethAmount) private {
        IUniswapV2Router02 _router = IUniswapV2Router02(config.router());
        address[] memory _path = new address[](2);
        _path[0] = _router.WETH();
        _path[1] = config.unibot();
        _router.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: _ethAmount
        }(0, _path, config.controller(), block.timestamp);
    }

    function _addLiquidity(
        uint256 _tokenAmount,
        uint256 _ethAmount
    ) private {
        IUniswapV2Router02 _router = IUniswapV2Router02(config.router());
        _approve(address(this), address(_router), _tokenAmount);
        _router.addLiquidityETH{value: _ethAmount}(
            address(this),
            _tokenAmount,
            0,
            0,
            config.lp(),
            block.timestamp
        );
    }

    function _calcTax(uint256 _amount, uint256 _tax) private pure returns (uint256) {
        if (_amount == 0 || _tax == 0) return 0;
        unchecked { return (_amount * _tax) / 10_000; }
    }

    receive() external payable {}
    fallback() external payable {}

    function _authorizeUpgrade(address _newImplementation)
    internal
    onlyOwner
    override
    {}
}
