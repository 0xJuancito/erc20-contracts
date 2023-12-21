// SPDX-License-Identifier: None
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./interfaces/IProofToken.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Factory.sol";

contract ProofToken is Ownable, Pausable, IERC20, IProofToken {
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) public excludedFromTxLimit;
    mapping(address => bool) public excludedFromMaxWallet;
    mapping(address => bool) public excludedFromFees;
    // mapping(address => bool) public airdropped;

    uint256 private constant _totalSupply = 100_000_000 * 10 ** _decimals;
    uint256 public maxTransfer;
    uint256 public maxWallet;
    // uint256 public airdroppedAmount;
    uint256 public immutable launchTime;
    uint256 public swapThreshold;

    uint256 public accAmountForStaking;
    uint256 public accAmountForRevenue;
    uint256 public accAmountForVentureFund;
    // uint256 public airdropReleaseTime;
    // uint256 public minHLDAmountForAirdrop;

    address public revenue;
    address public stakingContract;
    address public ventureFund;
    address public pair;
    // address public constant DEAD = 0x000000000000000000000000000000000000dEaD;

    Tax public taxForBuy;
    Tax public taxForSell;

    address public immutable router;

    bool public tradingEnable;
    bool private inSwapLiquidity;
    bool public swapEnable;

    string private constant _name = "PROOF";
    string private constant _symbol = "PROOF";

    uint8 private constant _decimals = 9;
    uint16 public constant FIXED_POINT = 1000;

    /// @dev Status flag to show airdrop is already processed or not.
    // bool public airdropProcessed;

    constructor(
        address _router,
        address _revenue,
        address _ventureFund,
        address _stakingContract,
        Tax memory _taxForBuy,
        Tax memory _taxForSell
    ) {
        require(_router != address(0), "zero router address");
        require(_revenue != address(0), "zero revenue address");
        require(_ventureFund != address(0), "zero ventureFund address");

        revenue = _revenue;
        ventureFund = _ventureFund;
        stakingContract = _stakingContract;

        _balances[address(this)] = _totalSupply;
        emit Transfer(address(0), address(this), _totalSupply);

        maxWallet = _totalSupply / 100; // 1%
        maxTransfer = (_totalSupply * 5) / 1000; // 0.5%

        router = _router;
        _createPair();

        swapThreshold = _totalSupply / 10000; // 0.01%

        excludedFromTxLimit[msg.sender] = true;
        excludedFromTxLimit[pair] = true;
        excludedFromTxLimit[address(this)] = true;

        excludedFromMaxWallet[msg.sender] = true;
        excludedFromMaxWallet[pair] = true;
        excludedFromMaxWallet[address(this)] = true;
        excludedFromMaxWallet[revenue] = true;
        excludedFromMaxWallet[stakingContract] = true;
        excludedFromMaxWallet[ventureFund] = true;

        excludedFromFees[msg.sender] = true;
        excludedFromFees[_revenue] = true;
        excludedFromFees[_ventureFund] = true;
        excludedFromFees[stakingContract] = true;

        taxForBuy = _taxForBuy;
        taxForSell = _taxForSell;
        swapEnable = true;

        launchTime = block.timestamp;
    }

    // !---------------- functions for ERC20 token ----------------!
    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function decimals() external pure returns (uint8) {
        return _decimals;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function airdrop(address[] memory users, uint256[] memory amounts) external onlyOwner {
        uint256 len = users.length;
        require(len == amounts.length, "lists must be equal");
        for (uint256 i = 0; i < len; i++) {
            _basicTransfer(amounts[i], address(this), users[i]);
            emit Transfer(address(this), users[i], amounts[i]);
        }
    }

    function transfer(
        address _recipient,
        uint256 _amount
    ) external override returns (bool) {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    function allowance(
        address _owner,
        address _spender
    ) external view override returns (uint256) {
        return _allowances[_owner][_spender];
    }

    function approve(
        address _spender,
        uint256 _amount
    ) external override returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) external override returns (bool) {
        uint256 currentAllowance = _allowances[_sender][msg.sender];
        require(currentAllowance >= _amount, "Transfer > allowance");
        _approve(_sender, msg.sender, currentAllowance - _amount);
        _transfer(_sender, _recipient, _amount);
        return true;
    }

    // !---------------- functions for ERC20 token ----------------!

    /// @inheritdoc IProofToken
    function excludeWalletsFromTxLimit(
        address[] memory _wallets,
        bool _exclude
    ) external override onlyOwner {
        uint256 length = _wallets.length;
        require(length > 0, "invalid array");

        for (uint256 i = 0; i < length; i++) {
            excludedFromTxLimit[_wallets[i]] = _exclude;
        }
    }

    /// @inheritdoc IProofToken
    function excludeWalletsFromMaxWallet(
        address[] memory _wallets,
        bool _exclude
    ) external override onlyOwner {
        uint256 length = _wallets.length;
        require(length > 0, "invalid array");
        for (uint256 i = 0; i < length; i++) {
            excludedFromMaxWallet[_wallets[i]] = _exclude;
        }
    }

    /// @inheritdoc IProofToken
    function excludeWalletsFromFees(
        address[] memory _wallets,
        bool _exclude
    ) external override onlyOwner {
        uint256 length = _wallets.length;
        require(length > 0, "invalid array");
        for (uint256 i = 0; i < length; i++) {
            excludedFromFees[_wallets[i]] = _exclude;
        }
    }

    /// @inheritdoc IProofToken
    function enableTrading(bool _enable) external override onlyOwner {
        tradingEnable = _enable;
    }

    /// @inheritdoc IProofToken
    function setMaxWallet(uint256 _maxWallet) external override onlyOwner {
        require(_maxWallet > 0, "invalid maxWallet");
        maxWallet = _maxWallet;
    }

    /// @inheritdoc IProofToken
    function setMaxTransfer(uint256 _maxTransfer) external override onlyOwner {
        require(_maxTransfer > 0, "invalid maxTransfer");
        maxTransfer = _maxTransfer;
    }

    /// @inheritdoc IProofToken
    function setSwapBackSettings(
        uint256 _swapThreshold,
        bool _swapEnable
    ) external override onlyOwner {
        swapEnable = _swapEnable;
        swapThreshold = _swapThreshold;
    }

    /// @inheritdoc IProofToken
    function setRevenue(address _revenue) external override onlyOwner {
        require(_revenue != address(0), "zero revenue address");
        excludedFromFees[revenue] = false;
        excludedFromFees[_revenue] = true;
        revenue = _revenue;
    }

    /// @inheritdoc IProofToken
    function setStakingContract(address _staking) external override onlyOwner {
        require(_staking != address(0), "zero staking contract address");
        if (stakingContract != address(0)) {
            excludedFromFees[stakingContract] = false;
        }
        excludedFromMaxWallet[_staking] = true;
        excludedFromFees[_staking] = true;
        stakingContract = _staking;
        
    }

    /// @inheritdoc IProofToken
    function setVentureFund(address _ventureFund) external override onlyOwner {
        require(_ventureFund != address(0), "zero revenue address");
        excludedFromFees[ventureFund] = false;
        excludedFromFees[_ventureFund] = true;
        ventureFund = _ventureFund;
    }

    /// @inheritdoc IProofToken
    function setTaxForBuy(Tax memory _tax) external override onlyOwner {
        require((_tax.revenueRate + _tax.stakingRate + _tax.ventureFundRate) <= 120, "12% max");

        taxForBuy = _tax;
    }

    /// @inheritdoc IProofToken
    function setTaxForSell(Tax memory _tax) external override onlyOwner {
        require((_tax.revenueRate + _tax.stakingRate + _tax.ventureFundRate) <= 170, "17% max");
        taxForSell = _tax;
    }

    /// @inheritdoc IProofToken
    function withdrawRestAmount(uint256 _amount) external override onlyOwner {
        uint256 availableAmount = _balances[address(this)];
        uint256 feeAmount = accAmountForRevenue +
            accAmountForStaking +
            accAmountForVentureFund;
        availableAmount -= feeAmount;
        require(availableAmount >= _amount, "not enough balance to withdraw");
        _transfer(address(this), owner(), _amount);
    }

    receive() external payable {}

    function _transfer(
        address _sender,
        address _recipient,
        uint256 _amount
    ) internal {
        require(_sender != address(0), "transfer from zero address");
        require(_recipient != address(0), "transfer to zero address");
        require(_amount > 0, "zero amount");
        require(_balances[_sender] >= _amount, "not enough amount to transfer");
        require(
            tradingEnable || (_recipient == stakingContract || _sender == stakingContract || _sender == owner() || _sender == address(this)),
            "trading is not enabled"
        );
        if (inSwapLiquidity || !tradingEnable) { 
            _basicTransfer(_amount, _sender, _recipient);
            emit Transfer(_sender, _recipient, _amount);
            return;
        }

        require(
            excludedFromTxLimit[_sender] || _amount <= maxTransfer,
            "over max transfer amount"
        );
        require(
            excludedFromMaxWallet[_recipient] ||
                _balances[_recipient] + _amount <= maxWallet,
            "exceeds to max wallet"
        );

        bool feelessTransfer = (excludedFromFees[_sender] ||
            excludedFromFees[_recipient]);

        if (_sender == pair) {
            // buy
            if (feelessTransfer) {
                _basicTransfer(_amount, _sender, _recipient);
            } else {
                _takeFee(taxForBuy, _amount, _sender, _recipient);
            }
        } else {
            _distributeFees();
            // sell or wallet transfer
            if (_recipient == pair) {
                // sell
                if (feelessTransfer) {
                    _basicTransfer(_amount, _sender, _recipient);
                } else {
                    _takeFee(taxForSell, _amount, _sender, _recipient);
                }
            } else {
                _basicTransfer(_amount, _sender, _recipient);
            }
        }

        emit Transfer(_sender, _recipient, _amount);
    }

    function _basicTransfer(
        uint256 _amount,
        address _sender,
        address _recipient
    ) internal {
        _balances[_sender] -= _amount;
        _balances[_recipient] += _amount;
    }

    function _takeFee(
        Tax memory _tax,
        uint256 _amount,
        address _sender,
        address _recipient
    ) internal {
        uint16 totalFee = _tax.revenueRate + _tax.stakingRate + _tax.ventureFundRate;

        uint256 feeAmount = (_amount * totalFee) / FIXED_POINT;
        uint256 revenueFee = (_amount * _tax.revenueRate) / FIXED_POINT;
        uint256 stakingFee = (_amount * _tax.stakingRate) / FIXED_POINT;
        uint256 ventureFee = feeAmount - revenueFee - stakingFee;

        accAmountForRevenue += revenueFee;
        accAmountForStaking += stakingFee;
        accAmountForVentureFund += ventureFee;

        uint256 transferAmount = _amount - feeAmount;

        _balances[address(this)] += feeAmount;
        _balances[_sender] -= _amount;
        _balances[_recipient] += transferAmount;
    }

    function _distributeFees() internal {
        uint256 feeAmount = accAmountForRevenue +
            accAmountForStaking +
            accAmountForVentureFund;

        if (feeAmount < swapThreshold || !swapEnable) {
            return;
        }

        if (feeAmount > 0) {
            inSwapLiquidity = true;
            _swapTokensToETH(feeAmount);
            uint256 swappedETHAmount = address(this).balance;
            inSwapLiquidity = false;

            uint256 revenueFee = (swappedETHAmount * accAmountForRevenue) /
                feeAmount;
            uint256 ventureFee = (swappedETHAmount * accAmountForVentureFund) /
                feeAmount;
            uint256 stakingFee = swappedETHAmount - revenueFee - ventureFee;

            _transferETH(revenue, revenueFee);
            _transferETH(stakingContract, stakingFee);
            _transferETH(ventureFund, ventureFee);
        }

        accAmountForRevenue = 0;
        accAmountForStaking = 0;
        accAmountForVentureFund = 0;
    }

    function _swapTokensToETH(uint256 _amount) internal {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _getWrappedToken();

        _approve(address(this), router, _amount);
            IUniswapV2Router02(router)
                .swapExactTokensForETHSupportingFeeOnTransferTokens(
                    _amount,
                    0,
                    path,
                    address(this),
                    block.timestamp
                );
    }

    function _transferETH(address _to, uint256 _amount) internal {
        if (_amount == 0) return;

        (bool sent, ) = _to.call{value: _amount}("");
        require(sent, "sending ETH failed");
    }

    function _approve(
        address _owner,
        address _spender,
        uint256 _amount
    ) private {
        require(_owner != address(0), "Approve from zero");
        require(_spender != address(0), "Approve to zero");
        _allowances[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }

    function _createPair() internal {
        address WToken = _getWrappedToken();
        pair = IUniswapV2Factory(IUniswapV2Router02(router).factory())
            .createPair(WToken, address(this));
    }

    function _getWrappedToken() internal view returns (address) {
        return
            IUniswapV2Router02(router).WETH();
    }
}
