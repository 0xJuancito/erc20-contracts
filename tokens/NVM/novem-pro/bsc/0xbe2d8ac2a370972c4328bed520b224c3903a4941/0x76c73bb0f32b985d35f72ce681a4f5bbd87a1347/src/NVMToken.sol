// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/presets/ERC20PresetMinterPauserUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title NNN Gold Token
 * @dev this contract is a Pausable ERC20 token with Burn and Mint functions.
 * By implementing EnhancedMinterPauser this contract also includes external
 * methods for setting a new implementation contract for the Proxy.
 * NOTE: All calls to this contract should be made through
 * the proxy, including admin actions.
 * Any call to transfer against this contract should fail.
 */
contract NVMToken is ERC20PresetMinterPauserUpgradeable, ERC20CappedUpgradeable, OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;

    //role for excluding addresses for feeless transfer
    bytes32 public constant FEE_EXCLUDED_ROLE = keccak256("FEE_EXCLUDED_ROLE");

    // fee percent represented in integer for example 400, will be used as 1/400 = 0,0025 percent
    uint32 public tokenTransferFeeDivisor;

    //address where the transfer fees will be sent
    address public feeAddress;

    event feeWalletAddressChanged(address newValue);
    event mintingFeePercentChanged(uint32 newValue);

    function __initializeNVM(uint256 cap) public initializer {
        __ERC20PresetMinterPauser_init("Novem Pro Token", "NVM");
        __ERC20Capped_init_unchained(cap);
    }

    function _mint(address account, uint256 amount)
        internal
        virtual
        override(ERC20CappedUpgradeable, ERC20Upgradeable)
    {
        super._mint(account, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20Upgradeable, ERC20PresetMinterPauserUpgradeable) {
        super._beforeTokenTransfer(from, to, amount);
    }

    /**
     * @dev overriding the openzeppelin _transfer method
     * if the sender address is not excluded substract transfer fee from the amount
     * and send the fee to the predefined fee address
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        if (hasRole(FEE_EXCLUDED_ROLE, _msgSender())) {
            super._transfer(sender, recipient, amount);
        } else {
            // transfer amount - fee
            super._transfer(sender, recipient, _calculateAmountSubTransferFee(amount));
            //transfer the fee to the predefined fee address
            super._transfer(sender, feeAddress, _calculateFee(amount));
        }
    }

    /**
     * @dev set the wallet address where fees will be collected
     */
    function setFeeWalletAddress(address _feeAddress) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Caller must have admin role to set minting fee address");
        require(address(0) != address(_feeAddress), "zero address is not allowed");

        feeAddress = _feeAddress;
        emit feeWalletAddressChanged(feeAddress);
    }

    /**
     * @dev sets the transfer fee
     * example: divisor 400 would equal to 0,05 percent; 1/400 = 0,0025/100
     */
    function setTransferFeeDivisor(uint32 _tokenTransferFeeDivisor) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Caller must have admin role to set minting fee percent");
        require(_tokenTransferFeeDivisor > 2, "Token transfer fee divisor must be greater than 0");

        tokenTransferFeeDivisor = _tokenTransferFeeDivisor;
        emit mintingFeePercentChanged(tokenTransferFeeDivisor);
    }

    /**
     * @dev calculates the total amount minus the the transfer fee
     */
    function _calculateAmountSubTransferFee(uint256 amount) private view returns (uint256) {
        return amount.sub(_calculateFee(amount));
    }

    /**
     * @dev calculates the transfer fee
     */
    function _calculateFee(uint256 amount) private view returns (uint256) {
        return amount.div(tokenTransferFeeDivisor);
    }

    function getFeeAddr() public view returns (address) {
        return feeAddress;
    }

    uint256[50] private __gap;
}
