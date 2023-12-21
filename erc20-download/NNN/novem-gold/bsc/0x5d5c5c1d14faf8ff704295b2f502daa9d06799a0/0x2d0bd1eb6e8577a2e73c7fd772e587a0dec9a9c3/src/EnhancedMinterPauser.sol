// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/presets/ERC20PresetMinterPauserUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @dev ERC20 token with minting, burning and pausable token transfers.
 *
 */
contract EnhancedMinterPauser is
    Initializable,
    ERC20PresetMinterPauserUpgradeable,
    OwnableUpgradeable
{
    using SafeMathUpgradeable for uint256;

    //role for excluding addresses for feeless transfer
    bytes32 public constant FEE_EXCLUDED_ROLE = keccak256("FEE_EXCLUDED_ROLE");

    // fee percent represented in integer for example 400, will be used as 1/400 = 0,0025 percent
    uint32 public tokenTransferFeeDivisor;

    //address where the transfer fees will be sent
    address public feeAddress;

    event feeWalletAddressChanged(address newValue);
    event mintingFeePercentChanged(uint32 newValue);

    function __EnhancedMinterPauser_init(
        string memory name,
        string memory symbol
    ) internal initializer {
        __ERC20_init_unchained(name, symbol);
        __ERC20PresetMinterPauser_init_unchained(name, symbol);
        __EnhancedMinterPauser_init_unchained();
        __Ownable_init();
    }

    function __EnhancedMinterPauser_init_unchained() internal initializer {
        _setupRole(FEE_EXCLUDED_ROLE, _msgSender());
        setFeeWalletAddress(0x9D1Cb8509A7b60421aB28492ce05e06f52Ddf727);
        setTransferFeeDivisor(400);
    }

    /**
     * @dev minting without 18 decimal places for convenience
     * if withFee = true calls the mintWithFee function
     * else sends the minted tokens without substracting a fee
     */
    function mintWithoutDecimals(
        address recipient,
        uint256 amount,
        bool withFee
    ) public {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "Caller must have admin role to mint"
        );
        if (withFee) {
            mintWithFee(recipient, amount * 1 ether);
        } else super._mint(recipient, amount * 1 ether);
    }

    /**
     * @dev mint tokens substract the fee, send the fee to the fee wallet
     * and send the final amount to the given address
     */
    function mintWithFee(address recipient, uint256 amount) public {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "Caller must have admin role to mint"
        );
        //transfer fee
        super._mint(feeAddress, _calculateFee(amount));
        super._mint(recipient, _calculateAmountSubTransferFee(amount));
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
            super._transfer(
                sender,
                recipient,
                amount
            );
        } else {
            // transfer amount - fee
            super._transfer(
                sender,
                recipient,
                _calculateAmountSubTransferFee(amount)
            );
            //transfer the fee to the predefined fee address
            super._transfer(sender, feeAddress, _calculateFee(amount));
        }
    }

    /**
     * @dev set the wallet address where fees will be collected
     */
    function setFeeWalletAddress(address _feeAddress) public {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "Caller must have admin role to set minting fee address"
        );
        require(address(0) != address(_feeAddress),
            "zero address is not allowed"
        );

        feeAddress = _feeAddress;
        emit feeWalletAddressChanged(feeAddress);
    }

    /**
     * @dev sets the transfer fee
     * example: divisor 400 would equal to 0,05 percent; 1/400 = 0,0025/100
     */
    function setTransferFeeDivisor(uint32 _tokenTransferFeeDivisor) public {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "Caller must have admin role to set minting fee percent"
        );
        require(
            _tokenTransferFeeDivisor > 2,
            "Token transfer fee divisor must be greater than 0"
        );

        tokenTransferFeeDivisor = _tokenTransferFeeDivisor;
        emit mintingFeePercentChanged(tokenTransferFeeDivisor);
    }

    /**
     * @dev calculates the total amount minus the the transfer fee
     */
    function _calculateAmountSubTransferFee(uint256 amount)
        private
        view
        returns (uint256)
    {
        return amount.sub(_calculateFee(amount));
    }

    /**
     * @dev calculates the transfer fee
     */
    function _calculateFee(uint256 amount) private view returns (uint256) {
        return amount.div(tokenTransferFeeDivisor);
    }

    uint256[50] private __gap;
}
