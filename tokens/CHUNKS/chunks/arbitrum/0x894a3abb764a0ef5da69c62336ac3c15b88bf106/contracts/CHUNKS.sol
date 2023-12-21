//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import "./ISwapContract.sol";


contract CHUNKS is Context, IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) public whiteList;

    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) private _isExcluded;
    address[] private _excluded;

    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal = 500_000_000 * 1 ether;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;
    bool public commissionActive = false;
    bool public whitListEnabled = false;

    string private _name = 'CHUNKS';
    string private _symbol = 'CHUNKS';
    uint8 private _decimals = 18;

    // Buy Fees
    uint256 public _liquidityFee = 50;
    uint256 public _reflectionFee = 100;
    uint256 public _nftHolderFee = 100;
    uint256 public _treasuryFee = 500;
    uint256 public _burnFee = 50;

    // Sell Fees
    uint256 public _sellLiquidityFee = 100;
    uint256 public _sellReflectionFee = 100;
    uint256 public _sellNftHoldersFee = 100;
    uint256 public _sellTreasuryFee = 400;
    uint256 public _sellBurnFee = 100;

    // FeeWallets

    address public liqGOBWallet;
    address public treasuryWallet;
    address public ambassadorPoolWallet;
    address public rewardsWallet;
    address public marketingWallet;
    address public nftHoldersPoolWallet;

    // current fee
    uint256 public _mainReflectionFee = 0;
    uint256 public _mainBurnFee = 0;
    uint256 public _mainLiquidityFee = 0;

    SwapContractInterface public swapper;
    // Anti whale
    uint256 public constant MAX_HOLDING_PERCENTS_DIVISOR = 10000;
    uint256 public constant PERCENTS_DIVISOR = 10000;
    uint256 public _maxHoldingPercents = 50;
    bool public antiWhaleEnabled;

    bool public sellIsActive;

    // Anti bot
    mapping(uint256 => bool) allowedBuyAmount;
    bool public antiBotEnabled;

    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = false;
    uint256 private numTokensSellToAddToLiquidity = 100000 * 10**18;

    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    error SellIsNotActive();

    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    constructor(
    ) {
        sellIsActive = false;
        _rOwned[_msgSender()] = _rTotal;

        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;

        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    function setSwapContract(address _address) public onlyOwner {
        swapper = SwapContractInterface(_address);
    }

    function setCommissionActive(bool _state) public onlyOwner {
        commissionActive = _state;
    }

    function activateSell() public onlyOwner {
        sellIsActive = true;
    }

    function setMarketingWallet(address newWallet) external onlyOwner {
        marketingWallet = newWallet;
    }

    function setNftHoldersPoolWallet(address newWallet) external onlyOwner {
        nftHoldersPoolWallet = newWallet;
    }

    function setRewardWallet(address newWallet) external onlyOwner {
        rewardsWallet = newWallet;
    }

    function setTreasuryWallet(address newWallet) external onlyOwner {
        treasuryWallet = newWallet;
    }

    function setAmbassadorPoolWallet(address newWallet) external onlyOwner {
        ambassadorPoolWallet = newWallet;
    }

    function setLiqGOBWallet(address newWallet) external onlyOwner {
        liqGOBWallet = newWallet;
    }

    function setLiqBuyFee(uint256 fee) public onlyOwner {
        _liquidityFee = fee;
    }

    function setLiqSellFee(uint256 fee) public onlyOwner {
        _sellLiquidityFee = fee;
    }

    function setReflectionBuyFee(uint256 fee) public onlyOwner {
        _reflectionFee = fee;
    }

    function setReflectionSellFee(uint256 fee) public onlyOwner {
        _sellReflectionFee = fee;
    }

    function setNftBuyFee(uint256 fee) public onlyOwner {
        _nftHolderFee = fee;
    }

    function setNftSellFee(uint256 fee) public onlyOwner {
        _sellNftHoldersFee = fee;
    }

    function setTreasuryBuyFee(uint256 fee) public onlyOwner {
        _treasuryFee = fee;
    }

    function setTreasurySellFee(uint256 fee) public onlyOwner {
        _sellTreasuryFee = fee;
    }

    function setBurnBuyFee(uint256 fee) public onlyOwner {
        _burnFee = fee;
    }

    function setBurnSellFee(uint256 fee) public onlyOwner {
        _sellBurnFee = fee;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
    public
    view
    override
    returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                'BEP20: transfer amount exceeds allowance'
            )
        );
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
    public
    virtual
    returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].add(addedValue)
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
    public
    virtual
    returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(
                subtractedValue,
                'BEP20: decreased allowance below zero'
            )
        );
        return true;
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function deliver(uint256 tAmount) public {
        address sender = _msgSender();
        require(!_isExcluded[sender], 'Excluded addresses cannot call this function');
        (uint256 rAmount, , , , , ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rTotal = _rTotal.sub(rAmount);
        _tFeeTotal = _tFeeTotal.add(tAmount);
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee)
    public
    view
    returns (uint256)
    {
        require(tAmount <= _tTotal, 'Amount must be less than supply');
        if (!deductTransferFee) {
            (uint256 rAmount, , , , , ) = _getValues(tAmount);
            return rAmount;
        } else {
            (, uint256 rTransferAmount, , , , ) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount) public view returns (uint256) {
        require(rAmount <= _rTotal, 'Amount must be less than total reflections');
        uint256 currentRate = _getRate();
        return rAmount.div(currentRate);
    }

    function excludeFromReward(address account) public onlyOwner {
        require(!_isExcluded[account], 'Account is already excluded');
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner {
        require(_isExcluded[account], 'Account is already excluded');
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function _transferBothExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
        uint256 rAmount,
        uint256 rTransferAmount,
        uint256 rFee,
        uint256 tTransferAmount,
        uint256 tFee,
        uint256 tLiquidity
        ) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _getValues(uint256 tAmount)
    private
    view
    returns (
        uint256,
        uint256,
        uint256,
        uint256,
        uint256,
        uint256
    )
    {
        (uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getTValues(
            tAmount
        );
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(
            tAmount,
            tFee,
            tLiquidity,
            _getRate()
        );
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee, tLiquidity);
    }

    function _getTValues(uint256 tAmount)
    private
    view
    returns (
        uint256,
        uint256,
        uint256
    )
    {
        uint256 tFee = calculateTaxFee(tAmount);
        uint256 tLiquidity = calculateLiquidityFee(tAmount);
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tLiquidity);
        return (tTransferAmount, tFee, tLiquidity);
    }

    function _getRValues(
        uint256 tAmount,
        uint256 tFee,
        uint256 tLiquidity,
        uint256 currentRate
    )
    private
    pure
    returns (
        uint256,
        uint256,
        uint256
    )
    {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rLiquidity);
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply)
                return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function _takeLiquidity(uint256 tLiquidity) private {
        uint256 currentRate = _getRate();
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        _rOwned[address(swapper)] = _rOwned[address(swapper)].add(rLiquidity);
        if (_isExcluded[address(swapper)])
            _tOwned[address(swapper)] = _tOwned[address(swapper)].add(tLiquidity);
    }

    function calculateTaxFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_mainReflectionFee).div(PERCENTS_DIVISOR);
    }

    function calculateLiquidityFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_mainLiquidityFee).div(PERCENTS_DIVISOR);
    }

    function activateSellFee() private {
        _mainReflectionFee = _sellReflectionFee;
        _mainLiquidityFee = _sellLiquidityFee;
        _mainBurnFee = _sellBurnFee;
    }

    function activateBuyFee() private {
        _mainReflectionFee = _reflectionFee;
        _mainLiquidityFee = _liquidityFee;
        _mainBurnFee = _burnFee;
    }

    function removeAllFee() private {
        _mainReflectionFee = 0;
        _mainLiquidityFee = 0;
        _mainBurnFee = 0;
    }

    function isExcludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFee[account];
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), 'BEP20: approve from the zero address');
        require(spender != address(0), 'BEP20: approve to the zero address');

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function swapAndLiquify(uint256 _amount) private lockTheSwap {
        swapper.swap(_amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), 'ERC20: transfer from the zero address');
        require(amount > 0, 'Transfer amount must be greater than zero');

        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is pancake pair.
        if (address(swapper) != address(0)) {
            uint256 contractTokenBalance = balanceOf(address(swapper));
            bool overMinTokenBalance = contractTokenBalance >= numTokensSellToAddToLiquidity;
            if (
                overMinTokenBalance &&
                !inSwapAndLiquify &&
                to == swapper.getPair() &&
                swapAndLiquifyEnabled
            ) {
                contractTokenBalance = numTokensSellToAddToLiquidity;
                //add liquidity
                swapAndLiquify(contractTokenBalance);
            }
        }

        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from, to, amount);

        if (antiWhaleEnabled) {
            uint256 maxAllowed = (_tTotal * _maxHoldingPercents) / MAX_HOLDING_PERCENTS_DIVISOR;
            if (address(swapper) != address(0)) {
                if (to == swapper.getPair()) {
                    require(
                        amount <= maxAllowed,
                        'Transacted amount exceed the max allowed value'
                    );
                } else {
                    require(
                        balanceOf(to) <= maxAllowed,
                        'Wallet balance exceeds the max limit'
                    );
                }
            } else {
                require(
                    balanceOf(to) <= maxAllowed,
                    'Wallet balance exceeds the max limit'
                );
            }
        }
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) private {
        if (!sellIsActive && sender == swapper.getPair()) revert SellIsNotActive();
        bool isSell = false;
        bool isBuy = false;
        if (recipient == swapper.getPair() && !_isExcludedFromFee[sender]) {
            activateSellFee();
            isSell = true;
        } else if (sender == swapper.getPair() && !_isExcludedFromFee[recipient]) {
            activateBuyFee();
            isBuy = true;
        }
        if (isSell || isBuy) {
            if (whitListEnabled) {
                require(whiteList[sender] || whiteList[recipient], 'Only white list user');
            }
            uint256 _burnAmount = amount.mul(_mainBurnFee).div(PERCENTS_DIVISOR);

            removeAllFee();

            _transferStandard(sender, address(0), _burnAmount);

            if (isBuy) {
                uint256 _treasuryAmount = amount.mul(_treasuryFee).div(PERCENTS_DIVISOR);
                uint256 _nftHolderAmount = amount.mul(_nftHolderFee).div(PERCENTS_DIVISOR);
                amount = amount.sub(_treasuryAmount).sub(_nftHolderAmount);

                _transferStandard(sender, treasuryWallet, _treasuryAmount);
                _transferStandard(sender, nftHoldersPoolWallet, _nftHolderAmount);
                activateBuyFee();
            } else {
                uint256 _sellTreasuryAmount = amount.mul(_sellTreasuryFee).div(PERCENTS_DIVISOR);
                uint256 _sellNftHoldersAmount = amount.mul(_sellNftHoldersFee).div(PERCENTS_DIVISOR);
                amount = amount.sub(_sellTreasuryAmount).sub(_sellNftHoldersAmount);

                _transferStandard(sender, treasuryWallet, _sellTreasuryAmount);
                _transferStandard(sender, nftHoldersPoolWallet, _sellNftHoldersAmount);
                activateSellFee();
            }
            amount = amount.sub(_burnAmount);
        }

        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(
                sender,
                recipient,
                amount
            );
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(
                sender,
                recipient,
                amount
            );
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(
                sender,
                recipient,
                amount
            );
        } else {
            _transferStandard(sender, recipient, amount);
        }
        removeAllFee();
    }

    function _transferStandard(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
        uint256 rAmount,
        uint256 rTransferAmount,
        uint256 rFee,
        uint256 tTransferAmount,
        uint256 tFee,
        uint256 tLiquidity
        ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
        uint256 rAmount,
        uint256 rTransferAmount,
        uint256 rFee,
        uint256 tTransferAmount,
        uint256 tFee,
        uint256 tLiquidity
        ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
        uint256 rAmount,
        uint256 rTransferAmount,
        uint256 rFee,
        uint256 tTransferAmount,
        uint256 tFee,
        uint256 tLiquidity
        ) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    function setMaxHoldingPercents(uint256 maxHoldingPercents) external onlyOwner {
        _maxHoldingPercents = maxHoldingPercents;
    }

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    function setWhiteListEnabled(bool _enabled) public onlyOwner {
        whitListEnabled = _enabled;
    }

    function addToWhiteList(address _user) public onlyOwner {
        whiteList[_user] = true;
    }

    function removeFromWhiteList(address _user) public onlyOwner {
        whiteList[_user] = false;
    }

    function addToWhiteListBatch(address[] memory _users) public onlyOwner {
        for (uint256 i = 0; i < _users.length; i++) {
            whiteList[_users[i]] = true;
        }
    }

    function removeFromWhiteListBatch(address[] memory _users) public onlyOwner {
        for (uint256 i = 0; i < _users.length; i++) {
            whiteList[_users[i]] = false;
        }
    }

    function setAntiWhale(bool enabled) external onlyOwner {
        antiWhaleEnabled = enabled;
    }
}
