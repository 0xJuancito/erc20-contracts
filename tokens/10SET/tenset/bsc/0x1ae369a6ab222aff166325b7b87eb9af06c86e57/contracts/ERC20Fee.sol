// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import { Ownable } from "./helpers/Ownable.sol";
import { MaintenanceMode } from "./helpers/MaintenanceMode.sol";
import { ERC20 } from "./ERC20.sol";
import { IFeeManager } from "./interfaces/IFeeManager.sol";

contract ERC20Fee is MaintenanceMode, ERC20 {
    /*///////////////////////////////////////////////////////////////
                            FEE-ON-TRANSFER STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 private constant MAX_FEE = 1000;
    uint256 private constant BPS_MULTIPLIER = 10000;

    mapping(address => bool) private _isExcludedFee;
    mapping(address => bool) private _isForcedFee;

    uint256 public _feeSell;
    uint256 public _feeBuy;
    uint256 public _feeTransfer;
    uint256 public burnPermyriad;

    address public feeRecipient;
    bool private isFeeManager;

    /*///////////////////////////////////////////////////////////////
                            FEE-ON-TRANSFER EVENTS
    //////////////////////////////////////////////////////////////*/

    event Fees(uint256 feeSell, uint256 feeBuy, uint256 feeTransfer);
    event ExcludeFee(address account, bool excluded);
    event ForcedFee(address account, bool forced);
    event FeeRecipientChanged(address feeRecipient, bool isFeeManager);

    /*///////////////////////////////////////////////////////////////
                            FEE-ON-TRANSFER LOGIC
    //////////////////////////////////////////////////////////////*/

    constructor(address owner) MaintenanceMode(owner) {}

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override transactionThrottler(sender, recipient, amount) maintenanceMode {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(_balances[sender] >= amount, "ERC20: transfer amount exceeds balance");

        uint256 fee = feeRecipient != address(0) ? _calcFee(sender, recipient, amount) : 0;
        uint256 burn = _isExcludedFee[sender] || _isExcludedFee[recipient] ? 0 : amount * burnPermyriad / 10000;
        uint256 receivedAmount = amount - fee - burn;

        if (fee > 0) {
            _balances[sender] -= fee;
            _balances[feeRecipient] += fee;
            emit Transfer(sender, feeRecipient, fee);

            if (isFeeManager && IFeeManager(feeRecipient).canSyncFee(sender, recipient)) {
                IFeeManager(feeRecipient).syncFee();
            }
        }

        if (burn > 0) {
            _burn(sender, burn);
        }

        unchecked {
            _balances[sender] -= receivedAmount;
        }
        _balances[recipient] += receivedAmount;
        emit Transfer(sender, recipient, receivedAmount);
    }

    function setExcludedFee(address account, bool excluded) external onlyOwner {
        _isExcludedFee[account] = excluded;
        emit ExcludeFee(account, excluded);
    }

    function setForcedFee(address account, bool forced) external onlyOwner {
        _isForcedFee[account] = forced;
        emit ForcedFee(account, forced);
    }

    function isExcludedFee(address account) external view returns (bool) {
        return _isExcludedFee[account];
    }

    function isForcedFee(address account) external view returns (bool) {
        return _isForcedFee[account];
    }

    function getFees()
        external
        view
        returns (
            uint256 feeSell,
            uint256 feeBuy,
            uint256 feeTransfer
        )
    {
        return (_feeSell, _feeBuy, _feeTransfer);
    }

    function setFees(
        uint256 feeSell,
        uint256 feeBuy,
        uint256 feeTransfer
    ) external onlyOwner {
        require(feeSell <= MAX_FEE && feeBuy <= MAX_FEE && feeTransfer <= MAX_FEE, "Fee is outside of range 0-1000");
        _feeSell = feeSell;
        _feeBuy = feeBuy;
        _feeTransfer = feeTransfer;
        emit Fees(feeSell, feeBuy, feeTransfer);
    }

    function changeFeeRecipient(address _feeRecipient, bool _isFeeManager) external onlyOwner {
        feeRecipient = _feeRecipient;
        isFeeManager = _isFeeManager;
        emit FeeRecipientChanged(feeRecipient, isFeeManager);
    }

    function _calcFee(
        address from,
        address to,
        uint256 amount
    ) private view returns (uint256 fee) {
        if (from != address(0) && to != address(0) && !_isExcludedFee[from] && !_isExcludedFee[to]) {
            if (_isForcedFee[to]) {
                fee = _calcBPS(amount, _feeSell);
            } else if (_isForcedFee[from]) {
                fee = _calcBPS(amount, _feeBuy);
            } else {
                fee = _calcBPS(amount, _feeTransfer);
            }
        }
    }

    function _calcBPS(uint256 amount, uint256 feeBPS) private pure returns (uint256) {
        return (amount * feeBPS) / BPS_MULTIPLIER;
    }

    function setBurnPermyriad(uint256 _burnPermyriad) external onlyOwner {
        burnPermyriad = _burnPermyriad;
    }

}
