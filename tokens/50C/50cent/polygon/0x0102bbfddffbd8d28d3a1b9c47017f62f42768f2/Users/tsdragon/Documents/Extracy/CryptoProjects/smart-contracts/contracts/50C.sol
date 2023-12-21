// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";

import "./owner/Operator.sol";
import "./interfaces/IOracle.sol";

contract FiftyCent is ERC20Burnable, Operator {

    mapping(uint256 => uint256) private taxRate;
    mapping(address => bool) public taxFreeSenders;
    mapping(address => bool) public taxFreeRecipients;

    address public oracle;
    bool public useOracle;
    uint256 public taxWithoutOracle;

    event TaxFreeSenderAdded(address indexed _address);
    event TaxFreeSenderRemoved(address indexed _address);
    event TaxFreeRecipientAdded(address indexed _address);
    event TaxFreeRecipientRemoved(address indexed _address);
    event TaxRateSet(uint256 index, uint256 rate);
    event TaxWithoutOracleSet(uint256 rate);
    event UseOracleSet(bool _useOracle);

    /**
     * @notice Constructs the 50 Cent ERC-20 contract.
     */
    constructor() public ERC20("50 Cent", "50C") {
        _mint(msg.sender, 104001 ether);

        useOracle = false;
        taxWithoutOracle = 0;

        // < 0.3
        taxRate[0] = 350;
        // 0.3 - 0.35
        taxRate[1] = 300;
        // 0.35 - 0.4
        taxRate[2] = 250;
        // 0.4 - 0.45
        taxRate[3] = 200; 
        // 0.45 - 0.5
        taxRate[4] = 100;
        // above 0.5
        taxRate[5] = 5;
    }

    /* ========== TAX ========== */

    function isTaxFreeSender(address _address) public view returns(bool isIndeed) {
        return taxFreeSenders[_address];
    }

    function isTaxFreeRecipient(address _address) public view returns(bool isIndeed) {
        return taxFreeRecipients[_address];
    }

    function getTaxRate(uint256 index) public view returns(uint256) {
        return taxRate[index];
    }

    function addTaxFreeSender(address newAddress) external onlySecondOperator returns(bool) {
        require(!isTaxFreeSender(newAddress), "Address already added.");
        taxFreeSenders[newAddress] = true;

        emit TaxFreeSenderAdded(newAddress);
        return true;
    }

    function removeTaxFreeSender(address oldAddress) external onlySecondOperator returns(bool) {
        require(isTaxFreeSender(oldAddress), "Address not found.");
        taxFreeSenders[oldAddress] = false;

        emit TaxFreeSenderRemoved(oldAddress);
        return true;
    }

    function addTaxFreeRecipient(address newAddress) external onlySecondOperator returns(bool) {
        require(!isTaxFreeRecipient(newAddress), "Address already added.");
        taxFreeRecipients[newAddress] = true;

        emit TaxFreeRecipientAdded(newAddress);
        return true;
    }

    function removeTaxFreeRecipient(address oldAddress) external onlySecondOperator returns(bool) {
        require(isTaxFreeRecipient(oldAddress), "Address not found.");
        taxFreeRecipients[oldAddress] = false;

        emit TaxFreeRecipientRemoved(oldAddress);
        return true;
    }

    function setTaxRate(uint256 index, uint256 rate) external onlySecondOperator {
        require(rate <= 450, "Rate not valid.");
        if (index >= 5) {
            require(rate <= 100, "Rate not valid.");
        }

        emit TaxRateSet(index, rate);
        taxRate[index] = rate;
    }

    function setTaxWithoutOracle(uint256 rate) external onlySecondOperator {
        require(rate <= 450, "Rate not valid.");

        taxWithoutOracle = rate;
        emit TaxWithoutOracleSet(rate);
    }

    function getCurrentTaxRate() public view returns (uint256) {
        if (useOracle == false) {
            return taxWithoutOracle;
        } else {
            uint256 price = getOraclePrice();
            if (price >= 50e16) {
                return taxRate[5];
            } else if (price >= 45e16) {
                return taxRate[4];
            } else if (price >= 40e16) {
                return taxRate[3];
            } else if (price >= 35e16) {
                return taxRate[2];
            } else if (price >= 30e16) {
                return taxRate[1];
            } else {
                return taxRate[0];
            }
        }
    }

    /* ========== ORACLE ========== */

    function setOracleAddress(address newOracle) external onlySecondOperator {
        oracle = newOracle;
    }

    function getOraclePrice() public view returns (uint256 paprPrice) {
        try IOracle(oracle).consult(address(this), 1e18) returns (uint144 price) {
            return uint256(price);
        } catch {
            revert("Failed to consult price from the oracle");
        }
    }

    function setUseOracle(bool _useOracle) external onlySecondOperator {
        useOracle = _useOracle;
        emit UseOracleSet(_useOracle);
    }

    /* ========== RECOVER UNSUPPORTED ========== */

    function governanceRecoverUnsupported(IERC20 _token, uint256 _amount, address _to) external onlySecondOperator {
        _token.transfer(_to, _amount);
    }

    /**
     * @notice Operator mints basis cash to a recipient
     * @param recipient_ The address of recipient
     * @param amount_ The amount of basis cash to mint to
     * @return whether the process has been done
     */
    function mint(address recipient_, uint256 amount_) public onlyOperator returns (bool) {
        uint256 balanceBefore = balanceOf(recipient_);
        _mint(recipient_, amount_);
        uint256 balanceAfter = balanceOf(recipient_);

        return balanceAfter > balanceBefore;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        bool isTaxFree = isTaxFreeSender(sender) || isTaxFreeRecipient(recipient);

        if (isTaxFree == true) {
            _transfer(sender, recipient, amount);
        } else {
            _transferWithTax(sender, recipient, amount);
        }
        
        _approve(sender, _msgSender(), allowance(sender, _msgSender()).sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function _transferWithTax(address sender, address recipient, uint256 amount) internal returns (bool) {
        uint256 taxAmount = amount.mul(getCurrentTaxRate()).div(1000);

        if (taxAmount > 0) {
            uint256 amountAfterTax = amount.sub(taxAmount);
            
            burnFrom(sender, taxAmount);
            _transfer(sender, recipient, amountAfterTax);
        } else {
            _transfer(sender, recipient, amount);
        }
        
        return true;
    }
}
