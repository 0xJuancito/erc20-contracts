// SPDX-License-Identifier: MIT

pragma solidity >0.6.12;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../lib/SafeMath8.sol";
import "../interfaces/IOracle.sol";
import "../interfaces/ITreasury.sol";

contract ArbiTen is ERC20Burnable, Ownable {
    using SafeMath8 for uint8;
    using SafeMath for uint;

    mapping(address => bool) public operators;

    /* ================= Taxation =============== */
    // Address of the Oracle
    address public oracle;
    // Address of the Tax Office
    address public taxOffice;

    ITreasury public treasury;

    // Current tax rate
    uint public taxRate;
    // Price threshold below which taxes will get burned
    uint public burnThreshold = 0;//1.10e18;
    // Address of the tax collector wallet
    address public taxCollectorAddress;

    // Should the taxes be calculated using the tax tiers
    bool public autoCalculateTax = false; // turn on at the end of deploy script

    // Tax Tiers
    uint[] public taxTiersTwaps = [0, 5e16, 6e16, 7e16, 8e16, 9e16, 9.5e16, 1e17, 1.05e17, 1.10e17, 1.20e17, 1.30e17, 1.40e17, 1.50e17];
    uint[] public taxTiersRates = [2000, 1500, 1500, 1500, 1000, 500, 200, 20, 20, 20, 20, 20, 20, 20];

    // Sender addresses excluded from Tax
    mapping(address => bool) public excludedAddresses;

    event TaxOfficeTransferred(address oldAddress, address newAddress);
    // Track DOLLAR burned
    event DollarBurned(address indexed from, address indexed to, uint amount);

    // Track DOLLAR minted
    event DollarMinted(address indexed from, address indexed to, uint amount);

    event SetTaxTiersTwap(uint indexed index, uint value);
    event SetTaxTiersRates(uint indexed from, uint value);

    modifier onlyPools() {
        require(ITreasury(treasury).hasPool(msg.sender), "!pools");
        _;
    }

    modifier onlyOperator() {
        require(operators[msg.sender], "Caller is not operator");
        _;
    }

    modifier onlyTaxOffice() {
        require(taxOffice == msg.sender, "Caller is not the tax office");
        _;
    }

    modifier onlyOperatorOrTaxOffice() {
        require(operators[msg.sender] || taxOffice == msg.sender, "Caller is not the operator or the tax office");
        _;
    }

    /**
     * @notice Constructs the ArbiTen ERC-20 contract.
     */
    constructor(ITreasury _treasury, uint _taxRate, address _taxCollectorAddress) public ERC20("ArbiTen", "ArbiTen") {
        require(_taxRate <= 2000, "tax equal or less than 20%");
        require(_taxCollectorAddress != address(0), "tax collector address must be non-zero address");

        operators[msg.sender] = true;

        excludeAddress(address(this));

        _mint(msg.sender, 1440 ether);
        
        taxRate = _taxRate;
        taxCollectorAddress = _taxCollectorAddress;

        treasury = _treasury;
    }

    /* ============= Taxation ============= */

    function getTaxTiersTwapsCount() public view returns (uint count) {
        return taxTiersTwaps.length;
    }

    function getTaxTiersRatesCount() public view returns (uint count) {
        return taxTiersRates.length;
    }

    function isAddressExcluded(address _address) public view returns (bool) {
        return excludedAddresses[_address];
    }

    function setTaxTiersTwap(uint8 _index, uint _value) public onlyTaxOffice returns (bool) {
        require(_index >= 0, "Index has to be higher than 0");
        require(_value <= 2000, "tax equal or less than 20%");
        require(_index < getTaxTiersTwapsCount(), "Index has to lower than count of tax tiers");
        if (_index > 0) {
            require(_value > taxTiersTwaps[_index - 1]);
        }
        if (_index < getTaxTiersTwapsCount().sub(1)) {
            require(_value < taxTiersTwaps[_index + 1]);
        }

        taxTiersTwaps[_index] = _value;

        emit SetTaxTiersTwap(_index, _value);
        return true;
    }

    function setTaxTiersRate(uint8 _index, uint _value) public onlyTaxOffice returns (bool) {
        require(_index >= 0, "Index has to be higher than 0");
        require(_index < getTaxTiersRatesCount(), "Index has to lower than count of tax tiers");
        taxTiersRates[_index] = _value;

        emit SetTaxTiersRates(_index, _value);
        return true;
    }

    function setBurnThreshold(uint _burnThreshold) public onlyTaxOffice returns (bool) {
        burnThreshold = _burnThreshold;
    }

    function _getArbiTenPrice() internal view returns (uint _ArbiTenPrice) {
        try IOracle(oracle).consult(address(this), 1e18) returns (uint144 _price) {
            return uint(_price);
        } catch {
            revert("ArbiTen: failed to fetch ArbiTen price from Oracle");
        }
    }

    function _updateTaxRate(uint _ArbiTenPrice) internal returns (uint){
        if (autoCalculateTax) {
            for (uint8 tierId = uint8(getTaxTiersTwapsCount()).sub(1); tierId >= 0; --tierId) {
                if (_ArbiTenPrice >= taxTiersTwaps[tierId]) {
                    require(taxTiersRates[tierId] < 10000, "tax equal or bigger to 100%");
                    taxRate = taxTiersRates[tierId];
                    return taxTiersRates[tierId];
                }
            }
        }
    }

    function enableAutoCalculateTax() public onlyTaxOffice {
        autoCalculateTax = true;
    }

    function disableAutoCalculateTax() public onlyTaxOffice {
        autoCalculateTax = false;
    }

    function setOperator(address operator, bool isOperator) public onlyOwner {
        require(operator != address(0), "operator address cannot be 0 address");
        operators[operator] = isOperator;
    }

    function setArbiTenOracle(address _oracle) public onlyOperatorOrTaxOffice {
        require(_oracle != address(0), "oracle address cannot be 0 address");
        oracle = _oracle;
    }

    function setTaxOffice(address _taxOffice) public onlyOperatorOrTaxOffice {
        require(_taxOffice != address(0), "tax office address cannot be 0 address");
        emit TaxOfficeTransferred(taxOffice, _taxOffice);
        taxOffice = _taxOffice;
    }

    function setTaxCollectorAddress(address _taxCollectorAddress) public onlyTaxOffice {
        require(_taxCollectorAddress != address(0), "tax collector address must be non-zero address");
        taxCollectorAddress = _taxCollectorAddress;
    }

    function setTaxRate(uint _taxRate) public onlyTaxOffice {
        require(!autoCalculateTax, "cannot set if auto calculate tax is enabled");
        require(_taxRate <= 2000, "tax equal or less than 20%");
        taxRate = _taxRate;
    }

    function excludeAddress(address _address) public onlyOperatorOrTaxOffice returns (bool) {
        require(!excludedAddresses[_address], "address can't be excluded");
        excludedAddresses[_address] = true;
        return true;
    }

    function includeAddress(address _address) public onlyOperatorOrTaxOffice returns (bool) {
        require(excludedAddresses[_address], "address can't be included");
        excludedAddresses[_address] = false;
        return true;
    }

    /**
     * @notice Operator mints ArbiTen to a recipient
     * @param recipient_ The address of recipient
     * @param amount_ The amount of ArbiTen to mint to

     */
    function mint(address recipient_, uint amount_) public onlyOperator {
        _mint(recipient_, amount_);
    }

    function burnFrom(address account, uint amount) public override onlyOperator {
        super.burnFrom(account, amount);
    }

    // Burn DOLLAR. Can be used by Pool only
    function poolBurnFrom(address _address, uint _amount) external onlyPools {
        super.burnFrom(_address, _amount);
        emit DollarBurned(_address, msg.sender, _amount);
    }

    // Mint DOLLAR. Can be used by Pool only
    function poolMint(address _address, uint _amount) external onlyPools {
        _mint(_address, _amount);
        emit DollarMinted(msg.sender, _address, _amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) public override returns (bool) {
        uint currentTaxRate = 0;
        bool burnTax = false;

        if (autoCalculateTax) {
            uint currentArbiTenPrice = _getArbiTenPrice();
            currentTaxRate = _updateTaxRate(currentArbiTenPrice);
            if (currentArbiTenPrice < burnThreshold) {
                burnTax = true;
            }
        }

        if (currentTaxRate == 0 || excludedAddresses[sender]) {
            _transfer(sender, recipient, amount);
        } else {
            _transferWithTax(sender, recipient, amount, burnTax);
        }

        _approve(sender, _msgSender(), allowance(sender, _msgSender()).sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function _transferWithTax(
        address sender,
        address recipient,
        uint amount,
        bool burnTax
    ) internal returns (bool) {
        uint taxAmount = amount.mul(taxRate).div(10000);
        uint amountAfterTax = amount.sub(taxAmount);

        if (burnTax) {
            // Burn tax
            super.burnFrom(sender, taxAmount);
        } else {
            // Transfer tax to tax collector
            _transfer(sender, taxCollectorAddress, taxAmount);
        }

        // Transfer amount after tax to recipient
        _transfer(sender, recipient, amountAfterTax);

        return true;
    }

    function amIOperator() public view returns (bool) {
        if (operators[msg.sender])
            return true;
        return false;
    }

    function setTreasuryAddress(ITreasury _treasury) public onlyOperator {
        require(address(_treasury) != address(0), "treasury address can't be 0!");
        treasury = _treasury;
    }
}
