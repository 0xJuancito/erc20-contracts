// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-0.8/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-0.8/token/ERC20/IERC20.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface IOracle {
    function update() external;

    function consult(address _token, uint256 _amountIn) external view returns (uint256 _amountOut);

    function twap(address _token, uint256 _amountIn) external view returns (uint256 _amountOut);
}

contract Based is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    using SafeMath for uint256;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant TAX_OFFICE_ROLE = keccak256("TAX_OFFICE_ROLE");

    // Initial distribution for the first 72h genesis pools
    uint256 public constant INITIAL_GENESIS_POOL_DISTRIBUTION = 40 ether;

    // Have the rewards been distributed to the pools
    bool public rewardPoolDistributed;

    /* ================= Taxation =============== */
    // Address of the Oracle
    address public oracle;

    // Current tax rate
    uint256 public taxRate;
    // Price threshold below which taxes will get burned
    uint256 public burnThreshold;
    // Address of the tax collector wallet
    address public taxCollectorAddress;

    // Should the taxes be calculated using the tax tiers
    bool public autoCalculateTax;

    // Tax Tiers
    uint256[] public taxTiersTwaps;
    uint256[] public taxTiersRates;

    // Sender addresses excluded from Tax
    mapping(address => bool) public excludedAddresses;

    modifier onlyOperatorOrTaxOffice() {
        require(hasRole(OPERATOR_ROLE, msg.sender) || hasRole(TAX_OFFICE_ROLE, msg.sender), "Based: Caller is not the operator or the tax office");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(uint256 _taxRate, address _taxCollectorAddress) initializer public { 
        __ERC20_init("BASED Token", "BASED");
        __ERC20Burnable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);

        // Mints 1 BASED to contract creator for initial pool setup
        require(_taxRate < 10000, "Based: Tax equal or bigger to 100%");

        excludeAddress(address(this));

        _mint(msg.sender, 1 ether);
        taxRate = _taxRate;
        taxCollectorAddress = _taxCollectorAddress;

        rewardPoolDistributed = false;
        burnThreshold = 1.10e18;
        taxTiersTwaps = [0, 5e17, 6e17, 7e17, 8e17, 9e17, 9.5e17, 1e18, 1.05e18, 1.10e18, 1.20e18, 1.30e18, 1.40e18, 1.50e18];
        taxTiersRates = [2000, 1900, 1800, 1700, 1600, 1500, 1500, 1500, 1500, 1400, 900, 400, 200, 100];
    }

    /* ============= Taxation ============= */

    function getTaxTiersTwapsCount() public view returns (uint256 count) {
        return taxTiersTwaps.length;
    }

    function getTaxTiersRatesCount() public view returns (uint256 count) {
        return taxTiersRates.length;
    }

    function isAddressExcluded(address _address) public view returns (bool) {
        return excludedAddresses[_address];
    }

    function setTaxTiersTwap(uint8 _index, uint256 _value) public onlyRole(TAX_OFFICE_ROLE) returns (bool) {
        require(_index >= 0, "Based: Index has to be higher than 0");
        require(_index < getTaxTiersTwapsCount(), "Based: Index has to lower than count of tax tiers");
        if (_index > 0) {
            require(_value > taxTiersTwaps[_index - 1], "Based: Value must be greater than previous");
        }
        if (_index < getTaxTiersTwapsCount().sub(1)) {
            require(_value < taxTiersTwaps[_index + 1], "Based: Value must be less than next");
        }
        taxTiersTwaps[_index] = _value;
        return true;
    }

    function setTaxTiersRate(uint8 _index, uint256 _value) public onlyRole(TAX_OFFICE_ROLE) returns (bool) {
        require(_index >= 0, "Based: Index has to be higher than 0");
        require(_index < getTaxTiersRatesCount(), "Based: Index has to lower than count of tax tiers");
        taxTiersRates[_index] = _value;
        return true;
    }

    function setBurnThreshold(uint256 _burnThreshold) public onlyRole(TAX_OFFICE_ROLE) returns (bool) {
        burnThreshold = _burnThreshold;
    }

    function _getBasedPrice() internal view returns (uint256 _basedPrice) {
        try IOracle(oracle).consult(address(this), 1e18) returns (uint256 _price) {
            return uint256(_price);
        } catch {
            revert("Based: Failed to fetch BASED price from Oracle");
        }
    }

    function _updateTaxRate(uint256 _basedPrice) internal returns (uint256) {
        if (autoCalculateTax) {
            for (uint8 tierId = uint8(getTaxTiersTwapsCount()) - 1; tierId >= 0; --tierId) {
                if (_basedPrice >= taxTiersTwaps[tierId]) {
                    require(taxTiersRates[tierId] < 10000, "Based: Tax equal or bigger to 100%");
                    taxRate = taxTiersRates[tierId];
                    return taxTiersRates[tierId];
                }
            }
        }
    }

    function enableAutoCalculateTax() public onlyRole(TAX_OFFICE_ROLE) {
        autoCalculateTax = true;
    }

    function disableAutoCalculateTax() public onlyRole(TAX_OFFICE_ROLE) {
        autoCalculateTax = false;
    }

    function setOracle(address _oracle) public onlyOperatorOrTaxOffice {
        require(_oracle != address(0), "Based: Oracle address cannot be 0 address");
        oracle = _oracle;
    }

    function setTaxOffice(address _taxOffice) public onlyOperatorOrTaxOffice {
        require(_taxOffice != address(0), "Based: Tax office address cannot be 0 address");
        _grantRole(TAX_OFFICE_ROLE, _taxOffice);
    }

    function setTaxCollectorAddress(address _taxCollectorAddress) public onlyRole(TAX_OFFICE_ROLE) {
        require(_taxCollectorAddress != address(0), "Based: Tax collector address must be non-zero address");
        taxCollectorAddress = _taxCollectorAddress;
    }

    function setTaxRate(uint256 _taxRate) public onlyRole(TAX_OFFICE_ROLE) {
        require(!autoCalculateTax, "Based: Auto calculate tax cannot be enabled");
        require(_taxRate < 10000, "Based: Tax equal or bigger to 100%");
        taxRate = _taxRate;
    }

    function excludeAddress(address _address) public onlyOperatorOrTaxOffice returns (bool) {
        require(!excludedAddresses[_address], "Based: Address can't be excluded");
        excludedAddresses[_address] = true;
        return true;
    }

    function includeAddress(address _address) public onlyOperatorOrTaxOffice returns (bool) {
        require(excludedAddresses[_address], "Based: Address can't be included");
        excludedAddresses[_address] = false;
        return true;
    }

    /**
     * @notice Operator mints BASED to a recipient
     * @param recipient_ The address of recipient
     * @param amount_ The amount of BASED to mint to
     * @return whether the process has been done
     */
    function mint(address recipient_, uint256 amount_) public onlyRole(OPERATOR_ROLE) returns (bool) {
        uint256 balanceBefore = balanceOf(recipient_);
        _mint(recipient_, amount_);
        uint256 balanceAfter = balanceOf(recipient_);

        return balanceAfter > balanceBefore;
    }

    function burn(uint256 amount) public override {
        super.burn(amount);
    }

    function burnFrom(address account, uint256 amount) public override onlyRole(OPERATOR_ROLE) {
        super.burnFrom(account, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        uint256 currentTaxRate = 0;
        bool burnTax = false;

        if (autoCalculateTax) {
            uint256 currentBasedPrice = _getBasedPrice();
            currentTaxRate = _updateTaxRate(currentBasedPrice);
            if (currentBasedPrice < burnThreshold) {
                burnTax = true;
            }
        }


        if (currentTaxRate == 0 || excludedAddresses[sender]) {
            _transfer(sender, recipient, amount);
        } else {
            _transferFromWithTax(sender, recipient, amount, burnTax);
        }

        _approve(sender, _msgSender(), allowance(sender, _msgSender()).sub(amount, "ERC20: Transfer amount exceeds allowance"));
        return true;
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        uint256 currentTaxRate = 0;
        bool burnTax = false;

        if (autoCalculateTax) {
            uint256 currentBasedPrice = _getBasedPrice();
            currentTaxRate = _updateTaxRate(currentBasedPrice);
            if (currentBasedPrice < burnThreshold) {
                burnTax = true;
            }
        }

        if (currentTaxRate == 0 || excludedAddresses[_msgSender()]) {
            _transfer(_msgSender(), recipient, amount);
        } else {
            _transferWithTax(_msgSender(), recipient, amount, burnTax);
        }

        return true;
    }

    function _transferWithTax(
        address sender,
        address recipient,
        uint256 amount,
        bool burnTax
    ) internal returns (bool) {
        uint256 taxAmount = amount.mul(taxRate).div(10000);
        uint256 amountAfterTax = amount.sub(taxAmount);

        if(burnTax) {
            // Burn tax
            super.burn(taxAmount);
        } else {
            // Transfer tax to tax collector
            _transfer(sender, taxCollectorAddress, taxAmount);
        }

        // Transfer amount after tax to recipient
        _transfer(sender, recipient, amountAfterTax);

        return true;
    }

    function _transferFromWithTax(
        address sender,
        address recipient,
        uint256 amount,
        bool burnTax
    ) internal returns (bool) {
        uint256 taxAmount = amount.mul(taxRate).div(10000);
        uint256 amountAfterTax = amount.sub(taxAmount);

        if(burnTax) {
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

    /**
     * @notice distribute to reward pool (only once)
     */
    function distributeReward(address _genesisPool) external onlyRole(OPERATOR_ROLE) {
        require(!rewardPoolDistributed, "Based: Only can distribute once");
        require(_genesisPool != address(0), "Based: Genesis pool must be non-zero address");
        rewardPoolDistributed = true;
        _mint(_genesisPool, INITIAL_GENESIS_POOL_DISTRIBUTION);
    }

    function governanceRecoverUnsupported(
        IERC20 _token,
        uint256 _amount,
        address _to
    ) external onlyRole(OPERATOR_ROLE) {
        _token.transfer(_to, _amount);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADER_ROLE)
        override
    {}
}
