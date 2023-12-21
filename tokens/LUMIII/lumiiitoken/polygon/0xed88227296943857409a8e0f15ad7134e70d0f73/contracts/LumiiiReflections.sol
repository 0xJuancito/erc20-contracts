pragma solidity ^0.6.6;

import "./LumiiiStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LumiiiReflections is LumiiiStorage, Ownable {
    /// @notice event emitted when SwapAndLiquifyEnabled is updated
    event SwapAndLiquifyEnabledUpdated(bool enabled);

    /// @notice event emitted when tokens are swapped and liquified
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    /// @notice event emitted when transfer occours
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// @notice modifier to show that contract is in swapAndLiquify
    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    /** 
        @notice Caclulate tax fees for transfer amount
        @param _amount Amount to calculate tax on
    */
    function calculateFees(uint256 _amount) public view returns (uint256, uint256, uint256, uint256) {
        uint256 tax = _amount.mul(_taxFee).div(10**2);
        uint256 liquidity= _amount.mul(_liquidityFee).div(10**2);
        uint256 charity = _amount.mul(_charityFee).div(10**2);
        uint256 ops = _amount.mul(_opsFee).div(10**2);

        return (tax, liquidity, charity, ops);
    }
    
    /** 
        @notice Sets maxTxPercent
    */
    function setMaxTxPercent(uint256 maxTxPercent) external onlyOwner() {
        _maxTxAmount = _tTotal.mul(maxTxPercent).div(
            10**2
        );
    }

    /** 
        @notice Sets new fees
    */
    function setFees(uint256 taxFee, uint256 liquidityFee, uint256 charityFee, uint256 opsFee) external onlyOwner() {
        require(opsFee + taxFee + liquidityFee + charityFee <= 10);

        _taxFee = taxFee;
        _liquidityFee = liquidityFee;
        _charityFee = charityFee;
        _opsFee = opsFee;

    }

    /** 
        @notice Enable/disable swapAndLiquify 
    */
    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    /** 
        @notice Get true and reflected values for a transfer amount
        @param tAmount true amount being transfered
    */
    function _getValues(uint256 tAmount) internal view returns (uint256, valueStruct memory, valueStruct memory) {
        // Get the true transfer, fee, and liquidity values
        valueStruct memory tValues = _getTValues(tAmount);
        // Get the reflected amount, trasfer amount, and reflected fee
        (uint256 rAmount, valueStruct memory rValues) = _getRValues(tAmount, tValues.fee, tValues.liquidity, 
                                                         tValues.charity, tValues.ops,  _getRate());

        return (rAmount, rValues, tValues);
    }

    /** 
        @notice Gets true values for transfer amount
        @param tAmount true amount being transfered
    */
    function _getTValues(uint256 tAmount) internal view returns (valueStruct memory) {
        // Get the tax fee for true amount
        valueStruct memory tValues;
        // Get tax amount
        (tValues.fee, tValues.liquidity, tValues.charity, tValues.ops) = calculateFees(tAmount);
        // Substract tax fee and liquidity fee from true amount, result is the true transfer amount
        tValues.transferAmount = tAmount.sub(tValues.fee).sub(tValues.liquidity).sub(tValues.charity).sub(tValues.ops);
        return tValues;
    }

     /** 
        @notice Gets reflected values for transfer amount
        @param tAmount true amount being transfered
        @param tFee true rewards tax amount
        @param tLiquidity true liquidity tax amount
        @param tCharity true charity tax amount
        @param tOps true operations tax amount
        @param currentRate current rate of conversion between true and reflected space
    */
    function _getRValues(uint256 tAmount, uint256 tFee, 
                         uint256 tLiquidity,  uint256 tCharity, 
                         uint256 tOps,  uint256 currentRate 
    ) internal pure returns (uint256, valueStruct memory) {
        valueStruct memory rValues;
        // Covert true amount to reflected amount using current conversion rate
        uint256 rAmount = tAmount.mul(currentRate);
        rValues.fee = tFee.mul(currentRate);
        // Calcualte reflected liquidity fee 
        rValues.liquidity = tLiquidity.mul(currentRate);
        // Get reflected charity fee
        rValues.charity = tCharity.mul(currentRate);
        // Get reflected operations fee
        rValues.ops = tOps.mul(currentRate);
        // Subtract reflexed tax and liqudity fee from reflected amount, result is reflected transfer amouunts
        rValues.transferAmount = rAmount.sub(rValues.fee).sub(rValues.liquidity).sub(rValues.charity).sub(rValues.ops);
        return (rAmount, rValues);
    }

    /** 
        @notice Adds liquidty to local pool
        @param tLiquidity Amount of liquidity to add
    */
    function _takeLiquidity(uint256 tLiquidity) internal {
        // Get conversion rate
        uint256 currentRate =  _getRate();
        // Calculate reflected liquidty
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        // Add reflected liqduity to contract balance
        _rOwned[address(this)] = _rOwned[address(this)].add(rLiquidity);
        // If contract is excluded from reflection fees, add true liqiduity
        if(_isExcluded[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)].add(tLiquidity);
    }

    /** 
        @notice Adds charity to charity wallet
        @param tCharity Amount of charity to add
    */
    function _takeCharity(uint256 tCharity) internal {
         // Get conversion rate
        uint256 currentRate =  _getRate();
        // Calculate reflected charity
        uint256 rCharity = tCharity.mul(currentRate);
        // Add reflected charity to contract balance
        _rOwned[_charityWallet] = _rOwned[_charityWallet].add(rCharity);
        // If contract is excluded from reflection fees, add true charity
        if(_isExcluded[_charityWallet])
            _tOwned[_charityWallet] = _tOwned[_charityWallet].add(tCharity);
    }

    /** 
        @notice Adds operation fee to operation wallet
        @param tOps Amount of operation fees to add
    */
    function _takeOps(uint256 tOps) internal {
         // Get conversion rate
        uint256 currentRate =  _getRate();
        // Calculate reflected charity
        uint256 rOps = tOps.mul(currentRate);
        // Add reflected charity to contract balance
        _rOwned[_opsWallet] = _rOwned[_opsWallet].add(rOps);
        // If contract is excluded from reflection fees, add true charity
        if(_isExcluded[_opsWallet])
            _tOwned[_opsWallet] = _tOwned[_opsWallet].add(tOps);
    }

    /// @notice Gets the rate of conversion r-space and t-space
    function _getRate() internal view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        // rSupply: unexcluded reflected total, tSupply: unexcluded true total
        return rSupply.div(tSupply); // Percentage of reflections each non-exluded holder will receive
    }

    /// @notice gets true and reflected supply for unexcluded accounts
    function _getCurrentSupply() internal view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;      
        // Account for wallet addresses that are exluded from reward => Allows for higher refleciton percentage
        // Subtract them from rSupply, tSupply
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    /** 
        @notice Account for (rewards) fee in true and reflected spaces
        @param rFee reflected fee amount
        @param tFee true fee amount
    */
    function _reflectFee(uint256 rFee, uint256 tFee) internal {
        // Caluclate new reflected total
        _rTotal = _rTotal.sub(rFee);
        // Add true fee to true fee total
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    /// @notice Remove all fees
    function removeAllFee() internal {
        if(_taxFee == 0 && _liquidityFee == 0 && _charityFee == 0 && _opsFee == 0) return;
        
        _previousTaxFee = _taxFee;
        _previousLiquidityFee = _liquidityFee;
        _previousCharityFee = _charityFee;
        _previousOpsFee = _opsFee;
        
        _taxFee = 0;
        _liquidityFee = 0;
        _charityFee = 0;
        _opsFee = 0;
    }
    
    /// @notice Restore all fees to previous value
    function restoreAllFee() internal {
        _taxFee = _previousTaxFee;
        _liquidityFee = _previousLiquidityFee;
        _charityFee = _previousCharityFee;
        _opsFee = _previousOpsFee;
    }
  

    /** 
        @notice Converts reflected to true amount
        @param rAmount Reflect token amount o convert
    */
    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        // Get the current reflection conversion rate
        uint256 currentRate =  _getRate();
        // Return reflected amount divided by current rate, equal to tAmount
        // rAmount / (rSupply/tSupply) = rAmount * (tSupply/rSupply) = tAmount
        return rAmount.div(currentRate);
    }
 
    /** 
        @notice Converts true to reflected amount 
        @param tAmount True amount to convert
        @param deductTransferFee Bool to check if fees should be deducted
    */
    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns(uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount,,) = _getValues(tAmount);
            return rAmount;
        } else {
            (,valueStruct memory rValues,) = _getValues(tAmount);
            return rValues.transferAmount;
        }
    }
    
    /** 
        @notice Excludes a user from rewards
        @param account Address to exclude
    */
    function excludeFromReward(address account) public onlyOwner() {
        require(!_isExcluded[account], "Account is already excluded");
        if(_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    /** 
    @notice Excludes a user from fees
    @param account Address to exclude
    */
    function excludeFromFee(address account) public onlyOwner() {
        _isExcludedFromFee[account] = true;
    }

    /** 
        @notice Include a user in rewards and fees
        @param account Address to include
    */
    function includeInReward(address account) public onlyOwner() {
        require(_isExcluded[account], "Account is already excluded");
        _isExcludedFromFee[account] = false;
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

    /// @notice Check if account is excluded
    function isExcluded(address account) public view returns (bool) {
      return _isExcluded[account];
    }

    /** 
        @notice Transfer helper to account for different transfer types
        @param sender Transfer sender
        @param recipient Transfer recipient
        @param amount Transfer amount
        @param takeFee Bool indicating if fees should be taken
    */
    function _tokenTransfer(address sender, address recipient, uint256 amount,bool takeFee) internal {
        if(!takeFee)
            removeAllFee();
        
        // Check if sendeer/recipient are excluded, if so _transferFromExcluded, otherwise _transferStandard
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

    /// @notice Transfer helper for when both sender/recipient are included in rewards and fees
    function _transferStandard(address sender, address recipient, uint256 tAmount) internal {
        // Convert from true to reflected space
        (uint256 rAmount, valueStruct memory rValues, valueStruct memory tValues) = _getValues(tAmount);

        // Subtract reflected amount from sender
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        // Add reflected transfer amount to recipient (taxed are deduceted)
        _rOwned[recipient] = _rOwned[recipient].add(rValues.transferAmount);
        // Take liqduity from transfer
        _takeLiquidity(tValues.liquidity);
        // Take charity fee from transfer
        _takeCharity(tValues.charity);
        // Take operations fee from transfer
        _takeOps(tValues.ops);
        // Update reflected total and true fee total
        _reflectFee(rValues.fee, tValues.fee);
        emit Transfer(sender, recipient, tValues.transferAmount);
    }

    /// @notice Transfer helper for when sender is included but recipient isnt
    function _transferToExcluded(address sender, address recipient, uint256 tAmount) internal {
        (uint256 rAmount, valueStruct memory rValues, valueStruct memory tValues) = _getValues(tAmount);
        
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tValues.transferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rValues.transferAmount);           
        _takeLiquidity(tValues.liquidity);
        // Take charity fee from transfer
        _takeCharity(tValues.charity);
        // Take operations fee from transfer
        _takeOps(tValues.ops);
        _reflectFee(rValues.liquidity, tValues.liquidity);
        emit Transfer(sender, recipient, tValues.liquidity);
    }
    
    /// @notice Transfer helper for when recipient is included but sender isnt
    function _transferFromExcluded(address sender, address recipient, uint256 tAmount) internal {
        (uint256 rAmount, valueStruct memory rValues, valueStruct memory tValues) = _getValues(tAmount);

        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rValues.transferAmount);   
        _takeLiquidity(tValues.liquidity);
        // Take charity fee from transfer
        _takeCharity(tValues.charity);
        // Take operations fee from transfer
        _takeOps(tValues.ops);
        _reflectFee(rValues.fee, tValues.fee);
        emit Transfer(sender, recipient, tValues.transferAmount);
    }

    /// @notice Transfer helper for when both sender/recipient are excluded from rewards and fees
    function _transferBothExcluded(address sender, address recipient, uint256 tAmount) internal {
        (uint256 rAmount, valueStruct memory rValues, valueStruct memory tValues) = _getValues(tAmount);

        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tValues.transferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rValues.transferAmount);        
        _takeLiquidity(tValues.liquidity);
        _reflectFee(rValues.liquidity, tValues.liquidity);
        emit Transfer(sender, recipient, tValues.transferAmount);
    }
    

}