// SPDX-License-Identifier: NOLICENSE
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Interfaces/IRouter.sol";
import "./Interfaces/IFactory.sol";

contract SaitaChain is IERC20, Ownable {

    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) private _isExcluded;
    mapping(address => bool) private _isBot;
    mapping(address => bool) private _isPair;

    mapping(address => bool) public canAirdrop;

    address[] private _excluded;
    
    bool private swapping;

    IRouter public router;
    address public pair;

    uint8 private constant _decimals = 9;
    uint256 private constant MAX = ~uint256(0);

    uint256 private _tTotal = 100 * 10**9 * 10**9;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));

    
    uint256 public swapTokensAtAmount = 1_000 * 10 ** 6;                                 // for bsc 
    uint256 public maxTxAmount = 100 * 10**9 * 10**9;
    
    // Anti Dump //
    mapping (address => uint256) public _lastTrade;
    bool public coolDownEnabled = false;
    uint256 public coolDownTime = 30 seconds;

    address public capitalAddress = 0xb3a50a36f988a1D44c248a042A068F822A5FaA29;             //change before mainnet deployment
    address public developmentAddress = 0xb3a50a36f988a1D44c248a042A068F822A5FaA29;         //change before mainnet deployment
    address public burnAddress = 0x000000000000000000000000000000000000dEaD;

    address public BUSD = 0x55d398326f99059fF775485246999027B3197955;                       //change to mainnet

    string private constant _name = "SaitaChain";
    string private constant _symbol = "STC";


    struct Taxes {
      uint256 reflection;
      uint256 capital;
      uint256 development;
      uint256 burn;
      uint256 treasury;
    }

    Taxes private buyTax = Taxes(0,0,20,0,0);
    Taxes private sellTax = Taxes(0,0,20,0,0);
    Taxes private walletToWalletTax = Taxes(0,0,20,0,0);


    struct TotFeesPaidStruct {
        uint256 reflection;
        uint256 capital;
        uint256 development;
        uint256 burn;
        uint256 treasury;
    }

    TotFeesPaidStruct public totFeesPaid;

    struct valuesFromGetValues{
      uint256 rAmount;
      uint256 rTransferAmount;
      uint256 rReflection;
      uint256 rCapital;
      uint256 rdevelopment;
      uint256 rBurn;
      uint256 rTreasury;
      uint256 tTransferAmount;
      uint256 tReflection;
      uint256 tCapital;
      uint256 tdevelopment;
      uint256 tBurn;
      uint256 tTreasury;
    }
    
    struct splitETHStruct{
        uint256 capital;
        uint256 development;
    }

    splitETHStruct private sellSplitETH = splitETHStruct(0,0);
    splitETHStruct private buySplitETH = splitETHStruct(0,0);
    splitETHStruct private walletToWalletSplitETH = splitETHStruct(0,0);


    struct ETHAmountStruct{
        uint256 capital;
        uint256 development;
    }

    ETHAmountStruct public ETHAmount;

    event FeesChanged();
    event BatchAirDropped(string _batchId);

    modifier lockTheSwap {
        swapping = true;
        _;
        swapping = false;
    }

    modifier addressValidation(address _addr) {
        require(_addr != address(0), 'SaitaChain :: Zero address');
        _;
    }

    modifier hasAirdropControl(address _addr) {
        require(canAirdrop[_addr], "SaitaChain :: No access");
        _;
    }

    constructor (address routerAddress, address owner_) Ownable(owner_) {
        IRouter _router = IRouter(routerAddress);
        address _pair = IFactory(_router.factory())
            .createPair(address(this), _router.WETH());

        router = _router;
        pair = _pair;
        
        addPair(pair);
    
        excludeFromReward(pair);

        _rOwned[owner()] = _rTotal;
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[capitalAddress] = true;
        _isExcludedFromFee[burnAddress] = true;
        _isExcludedFromFee[developmentAddress] = true;

        emit Transfer(address(0), owner(), _tTotal);
    }

    function name() public pure returns (string memory) {
        return _name;
    }
    function symbol() public pure returns (string memory) {
        return _symbol;
    }
    function decimals() public pure returns (uint8) {
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

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");

        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), currentAllowance - amount);

        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        _approve(_msgSender(), spender, currentAllowance - subtractedValue);

        return true;
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "SaitaChain :: Amount must be less than total reflections");
        uint256 currentRate =  _getRate();
        return rAmount/currentRate;
    }

    function excludeFromReward(address account) public onlyOwner {
        require(!_isExcluded[account], "SaitaChain :: Account is already excluded");
        require(_excluded.length <= 200, "SaitaChain :: Invalid length");
        require(account != owner(), "SaitaChain :: Owner cannot be excluded");
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


    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }


    function isExcludedFromFee(address account) public view returns(bool) {
        return _isExcludedFromFee[account];
    }

    function addPair(address _pair) public onlyOwner {
        _isPair[_pair] = true;
    }

    function removePair(address _pair) public onlyOwner {
        _isPair[_pair] = false;
    }

    function isPair(address account) public view returns(bool){
        return _isPair[account];
    }

    function setBuyTaxes(uint256 _reflection, uint256 _capital, uint256 _development, uint256 _burn, uint256 _treasury) public onlyOwner {
        buyTax.reflection = _reflection;
        buyTax.capital = _capital;
        buyTax.development = _development;
        buyTax.burn = _burn;
        buyTax.treasury = _treasury;
        emit FeesChanged();
    }

    function setSellTaxes(uint256 _reflection, uint256 _capital, uint256 _development, uint256 _burn, uint256 _treasury) public onlyOwner {
        sellTax.reflection = _reflection;
        sellTax.capital = _capital;
        sellTax.development = _development;
        sellTax.burn = _burn;
        sellTax.treasury = _treasury;
        emit FeesChanged();
    }

    function setWalletToWalletTaxes(uint256 _reflection, uint256 _capital, uint256 _development, uint256 _burn, uint256 _treasury) public onlyOwner {
        walletToWalletTax.reflection = _reflection;
        walletToWalletTax.capital = _capital;
        walletToWalletTax.development = _development;
        walletToWalletTax.burn = _burn;
        walletToWalletTax.treasury = _treasury;
        emit FeesChanged();
    }

    function setBuySplitETH(uint256 _capital, uint256 _development) public onlyOwner {
        buySplitETH.capital = _capital;
        buySplitETH.development = _development;
        emit FeesChanged();
    }

    function setSellSplitETH(uint256 _capital, uint256 _development) public onlyOwner {
        sellSplitETH.capital = _capital;
        sellSplitETH.development = _development;
        emit FeesChanged();
    }

    function setWalletToWalletSplitETH(uint256 _capital, uint256 _development) public onlyOwner {
        walletToWalletSplitETH.capital = _capital;
        walletToWalletSplitETH.development = _development;
        emit FeesChanged();
    }

    function _reflectReflection(uint256 rReflection, uint256 tReflection) private {
        _rTotal -=rReflection;
        totFeesPaid.reflection += tReflection;
    }

    function _takeTreasury(uint256 rTreasury, uint256 tTreasury) private {
        totFeesPaid.treasury += tTreasury;
        if(_isExcluded[address(this)]) _tOwned[address(this)] += tTreasury;
        _rOwned[address(this)] += rTreasury;
    }

    function _takeCapital(uint256 rCapital, uint256 tCapital) private {
        totFeesPaid.capital += tCapital;
        if(_isExcluded[capitalAddress]) _tOwned[capitalAddress] += tCapital;
        _rOwned[capitalAddress] +=rCapital;
    }
    
    function _takedevelopment(uint256 rdevelopment, uint256 tdevelopment) private {
        totFeesPaid.development += tdevelopment;
        if(_isExcluded[address(this)]) _tOwned[address(this)] += tdevelopment;
        _rOwned[address(this)] += rdevelopment;
    }

    function _takeBurn(uint256 rBurn, uint256 tBurn) private {
        totFeesPaid.burn += tBurn;
        if(_isExcluded[burnAddress])_tOwned[burnAddress] += tBurn;
        _rOwned[burnAddress] += rBurn;
    }

    function _getValues(uint256 tAmount, uint8 takeFee) private  returns (valuesFromGetValues memory to_return) {
        to_return = _getTValues(tAmount, takeFee);
        (to_return.rAmount, to_return.rTransferAmount, to_return.rReflection, to_return.rCapital,to_return.rdevelopment, to_return.rBurn, to_return.rTreasury) = _getRValues(to_return, tAmount, takeFee, _getRate());
        return to_return;
    }

    function _getTValues(uint256 tAmount, uint8 takeFee) private returns (valuesFromGetValues memory s) {
        if(takeFee == 0) {
          s.tTransferAmount = tAmount;
          return s;
        } else if(takeFee == 1){
            s.tReflection = (tAmount*sellTax.reflection)/1000;
            s.tCapital = (tAmount*sellTax.capital)/1000;
            s.tdevelopment = tAmount*sellTax.development/1000;
            s.tBurn = tAmount*sellTax.burn/1000;
            s.tTreasury = tAmount*sellTax.treasury/1000;
            if(sellTax.treasury > 0) {
                ETHAmount.capital += s.tTreasury*sellSplitETH.capital/sellTax.treasury;
                ETHAmount.development += (s.tTreasury*sellSplitETH.development/sellTax.treasury);
            }
            ETHAmount.development += s.tdevelopment;
            s.tTransferAmount = tAmount-s.tReflection-s.tCapital-s.tTreasury-s.tdevelopment-s.tBurn;
            return s;
        } else if(takeFee == 2) {
            s.tReflection = (tAmount*buyTax.reflection)/1000;
            s.tCapital = (tAmount*buyTax.capital)/1000;
            s.tdevelopment = tAmount*buyTax.development/1000;
            s.tBurn = tAmount*buyTax.burn/1000;
            s.tTreasury = tAmount*buyTax.treasury/1000;
            if(buyTax.treasury > 0) {
                ETHAmount.capital += s.tTreasury*buySplitETH.capital/buyTax.treasury;
                ETHAmount.development += (s.tTreasury*buySplitETH.development/buyTax.treasury);
            }
            ETHAmount.development += s.tdevelopment;
            s.tTransferAmount = tAmount-s.tReflection-s.tCapital-s.tTreasury-s.tdevelopment-s.tBurn;
            return s;
        } else {
            s.tReflection = tAmount*walletToWalletTax.reflection/1000;
            s.tdevelopment = tAmount*walletToWalletTax.development/1000;
            s.tBurn = tAmount*walletToWalletTax.burn/1000;
            s.tTreasury = tAmount*walletToWalletSplitETH.development/1000;
            ETHAmount.development += s.tTreasury + s.tdevelopment;
            s.tTransferAmount = tAmount-s.tReflection-s.tTreasury-s.tdevelopment-s.tBurn;
        }
        
    }

    function _getRValues(valuesFromGetValues memory s, uint256 tAmount, uint8 takeFee, uint256 currentRate) private pure returns (uint256 rAmount, uint256 rTransferAmount, uint256 rReflection,uint256 rCapital,uint256 rdevelopment,uint256 rBurn,uint256 rTreasury) {
        rAmount = tAmount*currentRate;

        if(takeFee == 0) {
          return(rAmount, rAmount, 0,0,0,0,0);
        } else if(takeFee == 1) {
            rReflection = s.tReflection*currentRate;
            rCapital = s.tCapital*currentRate;
            rTreasury = s.tTreasury*currentRate;
            rdevelopment = s.tdevelopment*currentRate;
            rBurn = s.tBurn*currentRate;
            rTransferAmount =  rAmount-rReflection-rCapital-rTreasury-rdevelopment-rBurn;
            return (rAmount, rTransferAmount, rReflection,rCapital,rdevelopment,rBurn,rTreasury);
        } else if(takeFee == 2) {
            rReflection = s.tReflection*currentRate;
            rCapital = s.tCapital*currentRate;
            rTreasury = s.tTreasury*currentRate;
            rdevelopment = s.tdevelopment*currentRate;
            rBurn = s.tBurn*currentRate;
            rTransferAmount =  rAmount-rReflection-rCapital-rTreasury-rdevelopment-rBurn;
            return (rAmount, rTransferAmount, rReflection,rCapital,rdevelopment,rBurn,rTreasury);
        } else {
            rReflection = s.tReflection*currentRate;
            rTreasury = s.tTreasury*currentRate;
            rdevelopment = s.tdevelopment*currentRate;
            rBurn = s.tBurn*currentRate;
            rTransferAmount =  rAmount-rReflection-rTreasury-rdevelopment-rBurn;
            return (rAmount, rTransferAmount, rReflection,0,rdevelopment,rBurn,rTreasury);
        }

    }

    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply/tSupply;
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply-_rOwned[_excluded[i]];
            tSupply = tSupply-_tOwned[_excluded[i]];
        }

        if (rSupply < _rTotal/_tTotal) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }


    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Zero amount");
        require(amount <= balanceOf(from),"Insufficient balance");
        require(!_isBot[from] && !_isBot[to], "SaitaChain :: You are a bot");
        require(amount <= maxTxAmount ,"SaitaChain :: Amount is exceeding maxTxAmount");

        if (coolDownEnabled) { 
            uint256 timePassed = block.timestamp - _lastTrade[from];
            require(timePassed > coolDownTime, "SaitaChain :: You must wait coolDownTime");
        }
        
        if(!_isExcludedFromFee[from] && !_isExcludedFromFee[to] && !swapping) {       //check this !swapping
            if(_isPair[from]) {                         // sell

                _tokenTransfer(from, to, amount, 1);

            } else if(_isPair[to]) {                    // buy
                _tokenTransfer(from, to, amount, 2);
            } else {
                _tokenTransfer(from, to, amount, 3);
            }
        } else {
            _tokenTransfer(from, to, amount, 0);
        }

        _lastTrade[from] = block.timestamp;
        
        if(!swapping && from != pair && to != pair && !_isExcludedFromFee[from] && !_isExcludedFromFee[to]) {
            address[] memory path = new address[](3);
                path[0] = address(this);
                path[1] = router.WETH();
                path[2] = BUSD;
            uint _amount = router.getAmountsOut(balanceOf(address(this)), path)[2];
            if(_amount >= swapTokensAtAmount) swapTokensForETH(balanceOf(address(this)));
        }

    }


    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(address sender, address recipient, uint256 tAmount, uint8 takeFee) private {
        valuesFromGetValues memory s = _getValues(tAmount, takeFee);

        if (_isExcluded[sender] ) {  //from excluded
                _tOwned[sender] = _tOwned[sender] - tAmount;
        }
        if (_isExcluded[recipient]) { //to excluded
                _tOwned[recipient] = _tOwned[recipient] + s.tTransferAmount;
        }

        _rOwned[sender] = _rOwned[sender]-s.rAmount;
        _rOwned[recipient] = _rOwned[recipient]+s.rTransferAmount;
        
        if(s.rReflection > 0 || s.tReflection > 0) _reflectReflection(s.rReflection, s.tReflection);
        if(s.rTreasury > 0 || s.tTreasury > 0) {
            _takeTreasury(s.rTreasury,s.tTreasury);
        }
        if(s.rCapital > 0 || s.tCapital > 0){
            _takeCapital(s.rCapital, s.tCapital);
            emit Transfer(sender, capitalAddress, s.tdevelopment);
        }
        if(s.rdevelopment > 0 || s.tdevelopment > 0){
            _takedevelopment(s.rdevelopment, s.tdevelopment);
            emit Transfer(sender, address(this), s.tdevelopment);
        }
        if(s.rBurn > 0 || s.tBurn > 0){
            _takeBurn(s.rBurn, s.tBurn);
            emit Transfer(sender, burnAddress, s.tBurn);
        }
        
        emit Transfer(sender, recipient, s.tTransferAmount);
        if(s.tTreasury > 0){
        emit Transfer(sender, address(this), s.tTreasury);
        }
    }

    function swapTokensForETH(uint256 tokenAmount) private lockTheSwap {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
                path[0] = address(this);
                path[1] = router.WETH();

        _approve(address(this), address(router), tokenAmount);
        // make the swap
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );

        (bool success, ) = capitalAddress.call{value: (ETHAmount.capital * address(this).balance)/tokenAmount}("");
        require(success, 'SaitaChain :: ETH_TRANSFER_FAILED');
        ETHAmount.capital = 0;

        (success, ) = developmentAddress.call{value: (ETHAmount.development * address(this).balance)/tokenAmount}("");
        require(success, 'SaitaChain :: ETH_TRANSFER_FAILED');
        ETHAmount.development = 0;
    }

    function updateCapitalWallet(address newWallet) external onlyOwner addressValidation(newWallet) {
        require(capitalAddress != newWallet, 'SaitaChain :: Wallet already set');
        capitalAddress = newWallet;
        _isExcludedFromFee[capitalAddress];
    }

    function updateBurnWallet(address newWallet) external onlyOwner addressValidation(newWallet) {
        require(burnAddress != newWallet, 'SaitaChain :: Wallet already set');
        burnAddress = newWallet;
        _isExcludedFromFee[burnAddress];
    }

    function updatedevelopmentWallet(address newWallet) external onlyOwner addressValidation(newWallet) {
        require(developmentAddress != newWallet, 'SaitaChain :: Wallet already set');
        developmentAddress = newWallet;
        _isExcludedFromFee[developmentAddress];
    }

    function updateStableCoin(address _BUSD) external onlyOwner  addressValidation(_BUSD) {
        require(BUSD != _BUSD, 'SaitaChain :: Wallet already set');
        BUSD = _BUSD;
    }

    function updateMaxTxAmt(uint256 amount) external onlyOwner {
        require(amount >= 100);
        maxTxAmount = amount * 10**_decimals;
    }

    function updateSwapTokensAtAmount(uint256 amount, uint256 stableTokenDecimal) external onlyOwner {
        require(amount >= 0);
        swapTokensAtAmount = amount * 10**stableTokenDecimal;
    }

    function updateCoolDownSettings(bool _enabled, uint256 _timeInSeconds) external onlyOwner{
        coolDownEnabled = _enabled;
        coolDownTime = _timeInSeconds * 1 seconds;
    }

    function setAntibot(address account, bool state) external onlyOwner{
        require(_isBot[account] != state, 'SaitaChain :: Value already set');
        _isBot[account] = state;
    }
    
    function bulkAntiBot(address[] memory accounts, bool state) external onlyOwner {
        require(accounts.length <= 100, "SaitaChain :: Invalid");
        for(uint256 i = 0; i < accounts.length; i++){
            _isBot[accounts[i]] = state;
        }
    }
    
    function updateRouterAndPair(address newRouter, address newPair) external onlyOwner {
        router = IRouter(newRouter);
        pair = newPair;
        addPair(pair);
    }
    
    function isBot(address account) public view returns(bool){
        return _isBot[account];
    }
    
    function airdropTokens(address[] memory recipients, uint256[] memory amounts, string memory _batchId) external hasAirdropControl(msg.sender) {
        require(recipients.length == amounts.length,"SaitaChain :: Invalid size");
         address sender = owner();

         for(uint256 i; i<recipients.length; i++){
            if(balanceOf(recipients[i]) > 0) revert("SaitaChain :: Already airdropped");
            address recipient = recipients[i];
            uint256 rAmount = amounts[i]*_getRate();
            _rOwned[sender] = _rOwned[sender]- rAmount;
            _rOwned[recipient] = _rOwned[recipient] + rAmount;
            emit Transfer(sender, recipient, amounts[i]);
         }

        emit BatchAirDropped(_batchId);

        }

    //Use this in case ETH are sent to the contract by mistake
    function rescueETH(uint256 weiAmount) external onlyOwner{
        require(address(this).balance >= weiAmount, "SaitaChain :: insufficient ETH balance");
        payable(owner()).transfer(weiAmount);
    }
    
    // Function to allow admin to claim *other* ERC20 tokens sent to this contract (by mistake)
    // Owner cannot transfer out catecoin from this smart contract
    function rescueAnyERC20Tokens(address _tokenAddr, address _to, uint _amount) public onlyOwner {
        IERC20(_tokenAddr).transfer(_to, _amount);
    }

    function setAirdropControl(address[] memory _addr, bool[] memory _access) external onlyOwner {
        require(_addr.length == _access.length, "SaitaChain :: Different length inputs");
        for(uint i = 0; i< _addr.length; i++) {
            canAirdrop[_addr[i]] = _access[i];
        }
    }

    receive() external payable {
    }

}