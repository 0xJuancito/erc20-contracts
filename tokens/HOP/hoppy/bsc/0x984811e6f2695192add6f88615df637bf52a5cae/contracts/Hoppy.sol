// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./Pancakeswap.sol";

contract Hoppy is IERC20, Ownable, Pausable {
    using SafeMath for uint256;
    using Address for address;

    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;
    mapping (address => mapping (address => uint256)) private _allowances;

    mapping (address => bool) private _isExcludedFromFee;
    mapping (address => bool) private _isExcluded;
    address[] private _excluded;

    string private constant NAME = "HOPPY";
    string private constant SYMBOL = "HOP";
    uint8 private constant DECIMALS = 9;

    uint256 public constant MAX_TOKEN_PER_TX = 4 * 10**9 * 10**9;
    uint256 public constant MAX_TOKEN_PER_ACC = 5 * 10**11 * 10**9;
    bool public isLimit = true;

    uint256 private constant MAX = ~uint256(0);
    uint256 private constant _tTotal = 100 * 10**12 * 10**9;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;

    uint256 public taxFee = 2;
    uint256 private _previousTaxFee;

    uint256 public liquidityFee = 2;
    uint256 private _previousLiquidityFee;
    uint256 private numTokensSellToAddToLiquidity = 4 * 10**9 * 10**9;
    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;

    uint256 public donationFee = 1;
    uint256 private _previousDonationFee;
    address public donationAddress = 0x58538AB4B440d039F96085abf2E3D87870890833;

    IPancakeswapRouter public pancakeswapRouter;
    address public pancakeswapPair;

    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 bnbReceived,
        uint256 tokensIntoLiquidity
    );

    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    constructor() {
        _tOwned[owner()] = _tTotal;
        _rOwned[owner()] = _rTotal;
        _isExcludedFromFee[owner()] = true;
        _isExcluded[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcluded[address(this)] = true;
        IPancakeswapRouter _pancakeswapRouter = IPancakeswapRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        pancakeswapPair = IPancakeswapFactory(_pancakeswapRouter.factory())
        .createPair(address(this), _pancakeswapRouter.WETH());
        pancakeswapRouter = _pancakeswapRouter;
    }

    //to receive BNB from pancakeswapRouter when swaping
    receive() external payable {}

    function setLimit(bool _isLimit) external onlyOwner() {
        isLimit = _isLimit;
    }

    function setPancakeswapRouterAddress(address _pancakeswapRouterAddress) external onlyOwner() {
        pancakeswapRouter = IPancakeswapRouter(_pancakeswapRouterAddress);
    }

    function setPancakeswapPairAddress(address _pancakeswapPairAddress) external onlyOwner() {
        pancakeswapPair = _pancakeswapPairAddress;
    }

    function setDonationAddress(address _donationAddress) external onlyOwner() {
        donationAddress = _donationAddress;
    }

    function excludeFromReward(address account) external onlyOwner() {
        require(!_isExcluded[account], "Account is already excluded");
        if(_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner() {
        require(_isExcluded[account], "Account is not excluded");
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

    function excludeFromFee(address account) external onlyOwner {
        _isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) external onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    function setTaxFeePercent(uint256 _taxFee) external onlyOwner() {
        require(_taxFee > 0 && _taxFee <= 5, "Invalid fee");
        taxFee = _taxFee;
    }

    function setLiquidityFeePercent(uint256 _liquidityFee) external onlyOwner() {
        require(_liquidityFee > 0 && _liquidityFee <= 5, "Invalid fee");
        liquidityFee = _liquidityFee;
    }

    function setDonationFeePercent(uint256 _donationFee) external onlyOwner() {
        require(_donationFee > 0 && _donationFee <= 5, "Invalid fee");
        donationFee = _donationFee;
    }

    function setSwapAndLiquifyEnabled(bool _enabled) external onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function isExcludedFromFee(address account) public view returns(bool) {
        return _isExcludedFromFee[account];
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns(uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount,,,,,) = _getValues(tAmount);
            return rAmount;
        } else {
            (,uint256 rTransferAmount,,,,) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate =  _getRate();
        return rAmount.div(currentRate);
    }

    function totalSupply() public pure override returns (uint256) {
        return _tTotal;
    }

    function name() public pure returns (string memory) {
        return NAME;
    }

    function symbol() public pure returns (string memory) {
        return SYMBOL;
    }

    function decimals() public pure returns (uint8) {
        return DECIMALS;
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _takeLiquidity(uint256 tLiquidity) private {
        uint256 currentRate =  _getRate();
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rLiquidity);
        if(_isExcluded[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)].add(tLiquidity);
    }

    function _donate(uint256 tAmount) private {
        uint256 tDonation = calculateDonationFee(tAmount);
        uint256 currentRate =  _getRate();
        uint256 rDonation = tDonation.mul(currentRate);
        _rOwned[donationAddress] = _rOwned[donationAddress].add(rDonation);
        if(_isExcluded[donationAddress])
            _tOwned[donationAddress] = _tOwned[donationAddress].add(tDonation);
    }

    function calculateTaxFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(taxFee).div(
            10**2
        );
    }

    function calculateLiquidityFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(liquidityFee).div(
            10**2
        );
    }

    function calculateDonationFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(donationFee).div(
            10**2
        );
    }

    function removeAllFee() private {
        if(taxFee == 0 && liquidityFee == 0) return;

        _previousTaxFee = taxFee;
        _previousLiquidityFee = liquidityFee;
        _previousDonationFee = donationFee;

        taxFee = 0;
        liquidityFee = 0;
        donationFee = 0;
    }

    function restoreAllFee() private {
        taxFee = _previousTaxFee;
        liquidityFee = _previousLiquidityFee;
        donationFee = _previousDonationFee;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        if (isLimit == true && from != owner() && to != owner()) {
            require(amount <= MAX_TOKEN_PER_TX, "Transfer amount exceeds the max transaction limit.");
            if (from == pancakeswapPair) {
                require(balanceOf(to).add(amount) < MAX_TOKEN_PER_ACC, "Recipient amount exceeds max balance limit");
            }
        }

        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is pancakeswap pair.
        uint256 liquidityAmount = balanceOf(address(this));
        bool overMinTokenBalance = liquidityAmount >= numTokensSellToAddToLiquidity;
        if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            from != pancakeswapPair &&
            swapAndLiquifyEnabled
        ) {
            liquidityAmount = numTokensSellToAddToLiquidity;
            swapAndLiquify(liquidityAmount);
        }

        //indicates if fee should be deducted from transfer
        bool takeFee = true;

        //if any account belongs to _isExcludedFromFee account then remove the fee
        if(_isExcludedFromFee[from] || _isExcludedFromFee[to]){
            takeFee = false;
        }

        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from,to,amount,takeFee);
    }

    function swapAndLiquify(uint256 amount) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = amount.div(2);
        uint256 otherHalf = amount.sub(half);

        // capture the contract's current BNB balance.
        // swap creates, and not make the liquidity event include any BNB that
        // this is so that we can capture exactly the amount of BNB that the
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for BNB
        swapTokensForBnb(half);

        // how much BNB did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);
        // add liquidity to pancakeswap
        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForBnb(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pancakeswapRouter.WETH();

        _approve(address(this), address(pancakeswapRouter), tokenAmount);

        // make the swap
        pancakeswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
        _approve(address(this), address(pancakeswapRouter), tokenAmount);
        // add the liquidity
        pancakeswapRouter.addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            owner(),
            block.timestamp
        );
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(address sender, address recipient, uint256 amount,bool takeFee) private {
        if(!takeFee)
            removeAllFee();

        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }

        if(!takeFee)
            restoreAllFee();
    }

    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, 
         uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getValues(tAmount);
         _rOwned[sender] = _rOwned[sender].sub(rAmount);
         _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
         _takeLiquidity(tLiquidity);
         _donate(tAmount);
         _reflectFee(rFee, tFee);
         emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, 
         uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getValues(tAmount);
         _rOwned[sender] = _rOwned[sender].sub(rAmount);
         _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
         _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
         _donate(tAmount);
         _takeLiquidity(tLiquidity);
         _reflectFee(rFee, tFee);
         emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, 
         uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getValues(tAmount);
         _tOwned[sender] = _tOwned[sender].sub(tAmount);
         _rOwned[sender] = _rOwned[sender].sub(rAmount);
         _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
         _donate(tAmount);
         _takeLiquidity(tLiquidity);
         _reflectFee(rFee, tFee);
         emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferBothExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, 
         uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getValues(tAmount);
         _tOwned[sender] = _tOwned[sender].sub(tAmount);
         _rOwned[sender] = _rOwned[sender].sub(rAmount);
         _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
         _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
         _donate(tAmount);
         _takeLiquidity(tLiquidity);
         _reflectFee(rFee, tFee);
         emit Transfer(sender, recipient, tTransferAmount);
    }

    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tDonation) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee,) = _getRValues(tAmount, tFee, tLiquidity, tDonation, _getRate());
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee, tLiquidity);
    }

    function _getTValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256) {
        uint256 tFee = calculateTaxFee(tAmount);
        uint256 tLiquidity = calculateLiquidityFee(tAmount);
        uint256 tDonation = calculateDonationFee(tAmount);
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tLiquidity).sub(tDonation);
        return (tTransferAmount, tFee, tLiquidity, tDonation);
    }

    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;      
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function _getRValues(uint256 tAmount, uint256 tFee, uint256 tLiquidity, uint256 tDonation, uint256 currentRate) private pure returns (uint256, uint256, uint256, uint256) {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        uint256 rDonation = tDonation.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rLiquidity).sub(rDonation);
        return (rAmount, rTransferAmount, rFee, rDonation);
    }
}
