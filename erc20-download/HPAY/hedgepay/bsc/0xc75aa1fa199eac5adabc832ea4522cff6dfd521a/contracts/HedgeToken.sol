// SPDX-License-Identifier: Unlicensed

// Solidity files have to start with this pragma.
// It will be used by the Solidity compiler to validate its version.
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "../interfaces/IFeeManager.sol";
import "../interfaces/IRewardManager.sol";

contract HedgeToken is ERC20PresetMinterPauser {
    
    // Transfers are disabled until the initial liquidity is locked
    bool public transfersEnabled = false;

    // Set this here for rebrading
    string private _name_;
    string private _symbol_;
    // DECIMALS
    uint256 public constant DECIMALS = 18;
   
    // Transaction fee in %
    uint256 public buyFee = 18;

    // Transaction fee in %
    uint256 public sellFee = 20;
   
    // Initial supply 250M
    uint256 public constant INITIAL_SUPPLY = 250_000_000 * (10**DECIMALS);

    // Max supply 1B,
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * (10**DECIMALS);

    // If accumulated fees are grather than this threshold we will call the FeeManager to process our fees
    uint256 public feeDistributionMinAmount = 2000;

    // The Fee Manager
    IFeeManager public feeManager;

    // The rewards manager
    IRewardManager public rewardsManager;

    // Exlcude from fees
    mapping(address => bool) private _excludedFromFee;

    // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
    // could be subject to a maximum transfer amount
    mapping (address => bool) public automatedMarketMakerPairs;

    // esential addresses needed for the system to work
    mapping (address => bool) public essentialAddress;

    // EVENTS
    event ExcludedFromFee(address indexed account, bool isExcluded);
    event UpdateFeeManger(address oldAddress, address newAddress);
    event UpdateRewardsManger(address oldAddress, address newAddress);
    event Log(string message);
    event LogBytes(bytes data);

    constructor() ERC20PresetMinterPauser("_", "_") {
        _mint(_msgSender(), INITIAL_SUPPLY);
        _name_ = "HedgePay";
        _symbol_ = "HPAY";
    }

    function name() public view override returns (string memory) {
        return _name_;
    }

    function symbol() public view override returns (string memory) {
        return _symbol_;
    }

    
    function setName(string calldata _name) external onlyRole(DEFAULT_ADMIN_ROLE)  {
        _name_ = _name;
    }

    function setSymbol(string calldata _symbol) external onlyRole(DEFAULT_ADMIN_ROLE)  {
        _symbol_ = _symbol;
    }

    function setBuyFee(uint8 newFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newFee <= 100, "Fee cannot be greater than 100%"); 
        buyFee = newFee;
    }

    function setSellFee(uint8 newFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newFee <= 100, "Fee cannot be greater than 100%"); 
        sellFee = newFee;
    }

    function enableTransfers() external onlyRole(DEFAULT_ADMIN_ROLE) {
       transfersEnabled = true;
    }

    function setFeeDistributionMinAmount(uint256 minAmount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        feeDistributionMinAmount = minAmount;
    }

    function isExcludedFromFee(address account) public view returns (bool) {
        return _excludedFromFee[account];
    }

    function updateEssentialAddress(address account, bool status) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(essentialAddress[account] != status, "HPAY: Address status allready set");
        essentialAddress[account] = status;
    }

    function excludeFromFee(address account, bool status) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_excludedFromFee[account] != status, "Address already exclude already set");
        _excludedFromFee[account] = status;
        emit ExcludedFromFee(account, status);
    }

    function _mint(address account, uint256 amount) internal override {
        require(totalSupply() + amount <= MAX_SUPPLY, "cap exceeded");

        uint256 oldBalance = balanceOf(account);

        super._mint(account, amount);
        if (address(rewardsManager) != address(0)) {
            rewardsManager.notifyBalanceUpdate(account, oldBalance);
        }
    }

    function _burn(address account, uint256 amount) internal override {
        uint256 oldBalance = balanceOf(account);
        super._burn(account, amount);
        if (address(rewardsManager) != address(0)) {
            rewardsManager.notifyBalanceUpdate(account, oldBalance);
        }
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        require(transfersEnabled || essentialAddress[from] || essentialAddress[to], "Transfers not allowed");

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        uint256 currentBalanceFrom = balanceOf(from);   
        uint256 currentBalanceTo = balanceOf(to);
        
        //  Deduct the fee if necessary
        uint256 fees = calculateFee(amount, from, to);
        if (fees > 0) {
            super._transfer(from, address(this), fees);
        }
        super._transfer(from, to, amount - fees);
        handleBalanceUpdate(from, to, currentBalanceFrom, currentBalanceTo);
        _distributeFee();
    }

    function calculateFee(uint256 amount, address from, address to) internal view returns(uint256) {
        if (_excludedFromFee[from] || _excludedFromFee[to]) {
            return 0;
        }
    
        if(automatedMarketMakerPairs[to]) {
            return (amount * sellFee) / 100;
        } else {
             return (amount * buyFee) / 100;
        }
    }

    function _distributeFee() internal {
        uint256 feeBalance = balanceOf(address(this));
        if (address(feeManager) != address(0) && feeBalance >= feeDistributionMinAmount) {
            // Call super transfer function directly to bypass fees and avoid loop
            super._transfer(address(this), address(feeManager), feeBalance);
            feeManager.processFee();
        }
    }

    function distributeFee() external { 
        require(address(feeManager) != address(0), "Fee Manager Not Set");
        require(balanceOf(address(this)) >= feeDistributionMinAmount, "Not enough fee balance" );
        _distributeFee();
    }

    function handleBalanceUpdate( address from, address to, uint256 oldBalanceFrom, uint256 oldBlanceTo) internal {
        if (address(rewardsManager) != address(0)) {
            rewardsManager.notifyBalanceUpdate(from, oldBalanceFrom);
            rewardsManager.notifyBalanceUpdate(to, oldBlanceTo) ;
        }
    }

    function updateFeeManager(address newAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newAddress != address(feeManager),"Fee Manager Address Unchanged");
        emit UpdateFeeManger(address(feeManager), newAddress); 
        feeManager = IFeeManager(newAddress); 
    }

    function updateRewardManager(address newAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newAddress != address(rewardsManager),"Rewards Manager Address Unchanged");
        emit UpdateRewardsManger(address(rewardsManager), newAddress);
        rewardsManager = IRewardManager(newAddress);  
    }

    function setAutomatedMarketMakerPair(address _address, bool status) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_address != address(0), "Pair cannot be 0x00 address");
        require(automatedMarketMakerPairs[_address] != status, "Pair already set");

        automatedMarketMakerPairs[_address] = status;
    }
}
