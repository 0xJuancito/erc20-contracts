// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./Ownable.sol";
import "./ERC20Permit.sol";
import "./interfaces/IUSAToken.sol";
import "./interfaces/ITokenSwapHelper.sol";

contract USAToken is IUSAToken, ERC20Permit, Ownable {
    uint256 public taxFeeOnBuy = 0;

    uint256 public taxFeeOnSell = 0;

    // max supply of the token (50 million)
    uint256 public immutable maximumSupply = 50 * 1e6 * 1e18;

    uint256 public minSwapAmount = 1e18;

    bool public swapToEthOnSell = false;

    bool public feesStatus = true;

    uint256 public constant percentDivider = 1e8;

    // the swapHelper allows the token to use potentially other types of dex designs
    ITokenSwapHelper public swapHelper;

    // the address that receives the dao tax
    address public daoTaxReceiver;

    // bool to prevernt the contract from being stuck in a loop on swapping
    bool internal swapping;

    // mappings with addresses that are excluded from fees
    mapping(address => bool) public isExcludedFromFee;

    mapping(address => bool) public approvedMinter;

    // mapping with addresses that are registered swap contracts (so pair contracts of DEXs)
    mapping(address => bool) internal registeredSwapContract;

    mapping(address => bool) public _isBlacklisted;

    modifier onlyMinter() {
        require(approvedMinter[_msgSender()], "USAToken: Caller is not a minter");
        _;
    }

    constructor(address _firstOwner, address _daoReceiver)
        ERC20Permit("USAToken")
        ERC20("USA Token", "USA")
        Ownable(_firstOwner)
    {
        daoTaxReceiver = _daoReceiver;
        isExcludedFromFee[address(this)] = true;
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()] - amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + (addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] - subtractedValue);
        return true;
    }

    // Internal functions

    function _transfer(address _from, address _to, uint256 _amount) internal override {
        require(_from != address(0), "USAToken: Transfer _from the zero address");
        require(_to != address(0), "USAToken: Transfer _to the zero address");
        require(_amount > 0, "USAToken:  Amount must be greater than zero");

        require(!_isBlacklisted[_from], "USAToken:  Blacklisted address");
        require(!_isBlacklisted[_to], "USAToken:  Blacklisted address");

        if (registeredSwapContract[_to] && swapToEthOnSell) {
            // only swap the collected tokens to ETH if the recipient is the swap contract (so if the user is selling)
            _distributeAndLiquify();
        }

        //indicates if fee should be deducted from transfer
        bool takeFee = true;

        //if any account belongs to isExcludedFromFee account then remove the fee
        if (isExcludedFromFee[_from] || isExcludedFromFee[_to] || !feesStatus) {
            // note: the transferhelper contract is excluded from fees by default
            takeFee = false;
        }

        _tokenTransfer(_from, _to, _amount, takeFee);
    }

    function _tokenTransfer(address _from, address _to, uint256 _amount, bool takeFee) private {
        unchecked {
            if (registeredSwapContract[_from] && takeFee) {
                // the user is buying - buy tax is applied
                uint256 allFee_;
                uint256 tTransferAmount_;
                allFee_ = totalBuyFeePerTx(_amount);
                tTransferAmount_ = _amount - allFee_;

                uint256 fromBalance_ = _balances[_from];

                if (fromBalance_ < _amount) {
                    revert ERC20InsufficientBalance(_from, fromBalance_, _amount);
                }

                // Overflow not possible: value <= fromBalance <= totalSupply.
                _balances[_from] = fromBalance_ - _amount;
                _balances[_to] += tTransferAmount_;

                emit Transfer(_from, _to, tTransferAmount_);

                _takeTokenFee(_from, allFee_);
            } else if (registeredSwapContract[_to] && takeFee) {
                // the user is selling - sell tax is applied
                uint256 allFee_ = totalSellFeePerTx(_amount);
                uint256 tTransferAmount_ = _amount - allFee_;

                uint256 fromBalance_ = _balances[_from];

                if (fromBalance_ < _amount) {
                    revert ERC20InsufficientBalance(_from, fromBalance_, _amount);
                }

                // Overflow not possible: value <= fromBalance <= totalSupply.
                _balances[_from] = fromBalance_ - _amount;
                _balances[_to] += tTransferAmount_;

                emit Transfer(_from, _to, tTransferAmount_);

                _takeTokenFee(_from, allFee_);
            } else {
                // the user is transfering - no tax is applied
                uint256 fromBalance_ = _balances[_from];

                if (fromBalance_ < _amount) {
                    revert ERC20InsufficientBalance(_from, fromBalance_, _amount);
                }

                // Overflow not possible: value <= fromBalance <= totalSupply.
                _balances[_from] = fromBalance_ - _amount;
                _balances[_to] += _amount;

                emit Transfer(_from, _to, _amount);
            }
        }
    }

    function _distributeAndLiquify() private {
        uint256 contractTokenBalance_ = balanceOf(address(this));

        if (contractTokenBalance_ >= minSwapAmount && !swapping) {
            swapping = true;

            _transfer(address(this), address(swapHelper), contractTokenBalance_);

            swapHelper.swapTokenForETH(contractTokenBalance_, 0);

            swapping = false;
        }
    }

    function _takeTokenFee(address _from, uint256 _amount) private {
        unchecked {
            _balances[address(this)] += _amount;
        }
        emit Transfer(_from, address(this), _amount);
    }

    // Minting and burning functions

    function mint(address _to, uint256 _amount) external onlyMinter {
        require(totalSupply() + _amount <= maximumSupply, "USAToken: Max supply reached");
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external onlyMinter {
        _burn(_from, _amount);
    }

    function manualSwap() external onlyOwner {
        uint256 contractTokenBalance_ = balanceOf(address(this));
        _transfer(address(this), address(swapHelper), contractTokenBalance_);
        swapHelper.swapTokenForETH(contractTokenBalance_, 0);
    }

    function withdrawTokens(address _token, address _to, uint256 _amount) external onlyOwner {
        IERC20(_token).transfer(_to, _amount);
        emit WithdrawTokens(_token, _to, _amount);
    }

    // Configuration functions

    function addRegisteredSwapContract(address _swapContract, bool _setting) external onlyOwner {
        registeredSwapContract[_swapContract] = _setting;
        emit RegisteredSwapContract(_swapContract, _setting);
    }

    function blacklistAddress(address account, bool value) external onlyOwner {
        _isBlacklisted[account] = value;
        emit BlacklistAddress(account, value);
    }

    function addMinter(address _minter) external onlyOwner {
        approvedMinter[_minter] = true;
        emit MinterAdded(_minter);
    }

    function removeMinter(address _minter) external onlyOwner {
        approvedMinter[_minter] = false;
        emit MinterRemoved(_minter);
    }

    function setMinSwapAmount(uint256 _minSwapAmount) external onlyOwner {
        minSwapAmount = _minSwapAmount;
        emit MinSwapAmountChanged(_minSwapAmount);
    }

    function setExcludedFromFee(address _address, bool _excluded) external onlyOwner {
        isExcludedFromFee[_address] = _excluded;
        emit ExcludedFromFeeChanged(_address, _excluded);
    }

    function setTaxFeeOnBuy(uint256 _taxFeeOnBuy) external onlyOwner {
        require(_taxFeeOnBuy <= 5 * 1e7, "USAToken: Tax fee on buy must be less than 50%");
        taxFeeOnBuy = _taxFeeOnBuy;
        emit TaxFeeOnBuyChanged(_taxFeeOnBuy);
    }

    function setTaxFeeOnSell(uint256 _taxFeeOnSell) external onlyOwner {
        require(_taxFeeOnSell <= 5 * 1e7, "USAToken: Tax fee on sell must be less than 50%");
        taxFeeOnSell = _taxFeeOnSell;
        emit TaxFeeOnSellChanged(_taxFeeOnSell);
    }

    function setSwapToEthOnSell(bool _swapToEthOnSell) external onlyOwner {
        swapToEthOnSell = _swapToEthOnSell;
        emit SwapToEthOnSellChanged(_swapToEthOnSell);
    }

    function setDaoTaxReceiver(address _daoTaxReceiver) external onlyOwner {
        daoTaxReceiver = _daoTaxReceiver;
        emit DaoTaxReceiverChanged(_daoTaxReceiver);
    }

    function changeSwapHelper(address _swapHelper) external onlyOwner {
        swapHelper = ITokenSwapHelper(_swapHelper);
        isExcludedFromFee[_swapHelper] = true;
        emit SwapHelperChanged(_swapHelper);
    }

    function enableOrDisableFees(bool _value) external onlyOwner {
        // Check if the new value is different _from the current state
        require(_value != feesStatus, "Value must be different _from current state");
        feesStatus = _value;
        emit FeeStatus(_value);
    }

    // View functions

    function isRegisteredSwapContract(address _swapContract) external view returns (bool) {
        return registeredSwapContract[_swapContract];
    }

    function totalBuyFeePerTx(uint256 _amount) public view returns (uint256 fee_) {
        fee_ = (_amount * taxFeeOnBuy) / percentDivider;
    }

    function totalSellFeePerTx(uint256 _amount) public view returns (uint256 fee_) {
        fee_ = (_amount * taxFeeOnSell) / percentDivider;
    }

    //to receive ETH from dexRouter when swapping
    receive() external payable {}
}
