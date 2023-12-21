// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../Operator.sol";
import "../interfaces/IOracle.sol";
import "../interfaces/IUniswapV2Router01.sol";
import "../interfaces/IUniswapV2Factory.sol";


contract XMatic is ERC20, Operator {
    using SafeMath for uint256;

    // Initial distribution for the first 24h genesis pools
    uint256 public constant INITIAL_GENESIS_POOL_DISTRIBUTION = 10000 ether;

    // Have the rewards been distributed to the pools
    bool public rewardPoolDistributed;

    uint256 private constant INITIAL_FRAGMENTS_SUPPLY = 15000 ether;

    // Rebase
    uint256 private constant MAX_SUPPLY = ~uint128(0);
    uint256 public TOTAL_GONS;
    uint256 private _gonsPerFragment;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcluded;
    address[] public excluded;
    address private daoFund;
    address private devFund;
    uint256 private _totalSupply;
    uint256 private constant maxExclusion = 20;
    address public oracle;

    // Tax
    address public taxOffice;
    uint256 private lastTimeRebase;
    uint256 public timeTaxAfterRebase;
    uint256 public taxRateAfterRebase;
    // Sender addresses excluded from Tax
    mapping(address => bool) public excludedTaxAddresses;
    mapping(address => bool) public marketLpPairs; // LP Pairs
    // Tax tiers
    uint256[] public taxTiersTwaps;
    uint256[] public taxTiersRates;
    // Taxes to be calculated using the tax tiers
    bool public enabledTax;
    bool public isSetOracle = false;

    address public dexRouter = address(0x7E5E5957De93D00c352dF75159FbC37d5935f8bF);
    address public wMaticAddress = address(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);

    /* =================== Events =================== */
    event LogRebase(uint256 indexed epoch, uint256 totalSupply, uint256 prevTotalSupply, uint256 prevRebaseSupply);
    event GrantExclusion(address indexed account);
    event RevokeExclusion(address indexed account);
    event DisableRebase(address indexed account);
    event EnableRebase(address indexed account);
    event SetTaxTiersTwap(uint8 _index, uint256 _value);
    event SetTaxTiersRate(uint8 _index, uint256 _value);
    event SetTokenOracle(address oldOracle, address newOracle);
    event SetTaxRateAfterRebase(uint256 oldValue, uint256 newValue);
    event SetTimeTaxAfterRebase(uint256 oldValue, uint256 newValue);
    event EnableCalculateTax();
    event DisableCalculateTax();

    constructor(address _daoFund, address _devFund) ERC20("xMATIC", "xMATIC") {
        require(_daoFund != address(0), "!_wethAddress");
        require(_devFund != address(0), "!_wethAddress");
        rewardPoolDistributed = false;
        _gonsPerFragment = 10 ** 18;
        _totalSupply = 0;
        lastTimeRebase = 0;
        daoFund = _daoFund;
        devFund = _devFund;
        taxTiersTwaps = [0, 8e17, 9e17, 101e16];
        taxTiersRates = [2000, 2000, 2000, 0];
        taxRateAfterRebase = 2000;
        // 20%
        timeTaxAfterRebase = 24 hours;

        taxOffice = msg.sender;

        IUniswapV2Router01 _dexRouter = IUniswapV2Router01(dexRouter);
        address dexPair = IUniswapV2Factory(_dexRouter.factory()).createPair(address(this), wMaticAddress);
        setMarketLpPairs(dexPair, true);

        _mint(msg.sender, INITIAL_FRAGMENTS_SUPPLY);
    }

    modifier onlyTaxOffice() {
        require(taxOffice == msg.sender, "taxOffice: caller is not the taxOffice");
        _;
    }

    function getDaoFund() external view returns (address){
        return daoFund;
    }

    function getDevFund() external view returns (address){
        return devFund;
    }

    function getExcluded() external view returns (address[] memory){
        return excluded;
    }

    function rebase(uint256 epoch, uint256 supplyDelta, bool negative) external onlyOperator returns (uint256){
        uint256 prevRebaseSupply = rebaseSupply();
        uint256 prevTotalSupply = _totalSupply;
        uint256 total = _rebase(supplyDelta, negative);

        emit LogRebase(epoch, total, prevTotalSupply, prevRebaseSupply);
        return total;
    }

    /**
	 * @dev Notifies Fragments contract about a new rebase cycle.
	 * @param supplyDelta The number of new fragment tokens to add into circulation via expansion.
	 * @param negative check increase or decrease token
	 * Return The total number of fragments after the supply adjustment.
	*/
    function _rebase(uint256 supplyDelta, bool negative) internal virtual returns (uint256) {
        // if supply delta is 0 nothing to rebase
        // if rebaseSupply is 0 nothing can be rebased
        if (supplyDelta == 0 || rebaseSupply() == 0) {
            return _totalSupply;
        }
        require(_totalSupply > supplyDelta, 'SupplyDelta must be lower than totalSupply');

        uint256[] memory excludedBalances = _burnExcludedAccountTokens();
        if (negative) {
            _totalSupply = _totalSupply.sub(uint256(supplyDelta));
        } else {
            _totalSupply = _totalSupply.add(uint256(supplyDelta));
        }

        if (_totalSupply > MAX_SUPPLY) {
            _totalSupply = MAX_SUPPLY;
        }

        _gonsPerFragment = TOTAL_GONS.div(_totalSupply);
        lastTimeRebase = block.timestamp;
        _mintExcludedAccountTokens(excludedBalances);

        return _totalSupply;
    }

    /**
	* @dev Exposes the supply available for rebasing. Essentially this is total supply minus excluded accounts
	* @return rebaseSupply The supply available for rebase
	*/
    function rebaseSupply() public view returns (uint256) {
        uint256 excludedSupply = 0;
        uint256 excludedLength = excluded.length;
        for (uint256 i = 0; i < excludedLength; i++) {
            excludedSupply = excludedSupply.add(balanceOf(excluded[i]));
        }
        return _totalSupply.sub(excludedSupply);
    }

    /**
	* @dev Burns all tokens from excluded accounts
	* @return excludedBalances The excluded account balances before burn
	*/
    function _burnExcludedAccountTokens() private returns (uint256[] memory excludedBalances){
        uint256 excludedLength = excluded.length;
        excludedBalances = new uint256[](excludedLength);
        for (uint256 i = 0; i < excludedLength; i++) {
            address account = excluded[i];
            uint256 balance = balanceOf(account);
            excludedBalances[i] = balance;
            if (balance > 0) _burn(account, balance);
        }

        return excludedBalances;
    }

    /**
	* @dev Mints tokens to excluded accounts
	* @param excludedBalances The amount of tokens to mint per address
	*/
    function _mintExcludedAccountTokens(uint256[] memory excludedBalances) private {
        uint256 excludedLength = excluded.length;
        for (uint256 i = 0; i < excludedLength; i++) {
            if (excludedBalances[i] > 0)
                _mint(excluded[i], excludedBalances[i]);
        }
    }

    /**
	 * @dev Grant an exclusion from rebases
	 * @param account The account to grant exclusion
	*/
    function grantRebaseExclusion(address account) external onlyOperator {
        if (_isExcluded[account]) return;
        require(excluded.length <= maxExclusion, 'Too many excluded accounts');
        _isExcluded[account] = true;
        excluded.push(account);
        emit GrantExclusion(account);
    }

    /**
     * @dev Revokes an exclusion from rebases
	 * @param account The account to revoke
	*/
    function revokeRebaseExclusion(address account) external onlyOperator {
        require(_isExcluded[account], 'Account is not already excluded');
        uint256 excludedLength = excluded.length;
        for (uint256 i = 0; i < excludedLength; i++) {
            if (excluded[i] == account) {
                excluded[i] = excluded[excludedLength - 1];
                _isExcluded[account] = false;
                excluded.pop();
                emit RevokeExclusion(account);
                return;
            }
        }
    }

    //---OVERRIDE FUNCTION---
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address who) public view override returns (uint256) {
        if (_gonsPerFragment == 0) return 0;
        return _balances[who].div(_gonsPerFragment);
    }

    function _mint(address account, uint256 amount) internal virtual override {
        require(account != address(0), 'ERC20: transfer to the zero address');
        require(amount > 0, "ERC20: Can't mint 0 tokens");

        TOTAL_GONS = TOTAL_GONS.add(_gonsPerFragment.mul(amount));
        _totalSupply = _totalSupply.add(amount);

        _balances[account] = _balances[account].add(
            amount.mul(_gonsPerFragment)
        );

        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual override {
        require(account != address(0), 'ERC20: burn from the zero address');
        uint256 accountBalance = _balances[account];
        require(
            accountBalance >= amount.mul(_gonsPerFragment),
            'ERC20: burn amount exceeds balance'
        );
    unchecked {
        _balances[account] = _balances[account].sub(
            amount.mul(_gonsPerFragment)
        );
    }

        TOTAL_GONS = TOTAL_GONS.sub(_gonsPerFragment.mul(amount));
        _totalSupply = _totalSupply.sub(amount);

        emit Transfer(account, address(0), amount);
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, _allowances[owner][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual override returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = _allowances[owner][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
    unchecked {
        _approve(owner, spender, currentAllowance - subtractedValue);
    }

        return true;
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual override {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transferBase(
        address from,
        address to,
        uint256 amount
    ) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        _beforeTokenTransfer(from, to, amount);

        uint256 gonValue = amount.mul(_gonsPerFragment);
        uint256 fromBalance = _balances[from];
        require(fromBalance >= gonValue, "ERC20: transfer amount exceeds balance");
        _balances[from] = _balances[from].sub(gonValue);
        _balances[to] = _balances[to].add(gonValue);
        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        require(from != address(0), "zero address");
        require(to != address(0), "zero address");
        require(daoFund != address(0), "require to set daoFund address");

        if (enabledTax) {
            uint256 taxAmount = 0;

            if (marketLpPairs[to] && !excludedTaxAddresses[from]) {
//                _updatePrice();
                uint256 currentTokenPrice = _getTokenPrice();
                uint256 currentTaxRate = calculateTaxRate(currentTokenPrice);
                if (currentTaxRate > 0) {
                    taxAmount = amount.mul(currentTaxRate).div(10000);
                }
            }

            if (taxAmount > 0)
            {
                amount = amount.sub(taxAmount);
                _transferBase(from, daoFund, taxAmount);
            }
        }

        _transferBase(from, to, amount);
    }

    /**
     * @notice Operator mints Token to a recipient
     * @param recipient_ The address of recipient
     * @param amount_ The amount of Token to mint to
     * @return whether the process has been done
    */
    function mint(address recipient_, uint256 amount_) external onlyOperator returns (bool) {
        uint256 balanceBefore = balanceOf(recipient_);
        _mint(recipient_, amount_);
        uint256 balanceAfter = balanceOf(recipient_);
        return balanceAfter > balanceBefore;
    }

    function burn(uint256 amount) external {
        if (amount > 0) _burn(_msgSender(), amount);
    }
    //---END OVERRIDE FUNCTION---

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), allowance(sender, _msgSender()).sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    /**
     * @notice distribute to reward pool (only once)
     */
    function distributeReward(
        address _genesisPool
    ) external onlyOwner {
        require(!rewardPoolDistributed, "only can distribute once");
        require(_genesisPool != address(0), "!_genesisPool");
        rewardPoolDistributed = true;
        _mint(_genesisPool, INITIAL_GENESIS_POOL_DISTRIBUTION);
    }

    function setDaoFund(address _daoFund) external onlyOperator {
        require(_daoFund != address(0), "Invalid address");
        daoFund = _daoFund;
    }

    function setDevFund(address _devFund) external onlyOperator {
        require(_devFund != address(0), "Invalid address");
        devFund = _devFund;
    }

    function isDaoFund(address _address) external view returns (bool) {
        return _address == daoFund;
    }

    function _getTokenPrice() internal view returns (uint256) {
        try IOracle(oracle).consult(address(this), 1e18) returns (uint144 _price) {
            return uint256(_price);
        } catch {
            revert("Error: Failed to fetch token price from Oracle");
        }
    }

    function _updatePrice() internal {
        try IOracle(oracle).update() {} catch {
            revert("Error: failed to update price from the oracle");
        }
    }

    function setTokenOracle(address _oracle) external onlyTaxOffice {
        require(!isSetOracle, "Only can setTokenOracle once");
        require(_oracle != address(0), "Oracle address cannot be 0 address");
        emit SetTokenOracle(oracle, _oracle);
        oracle = _oracle;
        isSetOracle = true;
    }

    function calculateTaxRate(uint256 _tokenPrice) public view returns (uint256) {
        uint256 taxTiersTwapsCount = taxTiersTwaps.length;
        uint256 taxRate = 0;
        if (block.timestamp >= lastTimeRebase && block.timestamp < lastTimeRebase.add(timeTaxAfterRebase)) {
            return taxRateAfterRebase;
        }
        for (uint8 tierId = uint8(taxTiersTwapsCount.sub(1)); tierId >= 0; --tierId) {
            if (_tokenPrice >= taxTiersTwaps[tierId]) {
                taxRate = taxTiersRates[tierId];
                break;
            }
        }

        return taxRate;
    }

    function setTaxTiersTwap(uint8 _index, uint256 _value) external onlyTaxOffice returns (bool) {
        uint256 taxTiersTwapsCount = taxTiersTwaps.length;
        require(_index < uint8(taxTiersTwapsCount), "Index has to lower than count of tax tiers");
        if (_index > 0) {
            require(_value > taxTiersTwaps[_index - 1]);
        }
        if (_index < uint8(taxTiersTwapsCount.sub(1))) {
            require(_value < taxTiersTwaps[_index + 1]);
        }
        taxTiersTwaps[_index] = _value;
        emit SetTaxTiersTwap(_index, _value);
        return true;
    }

    function setTaxTiersRate(uint8 _index, uint256 _value) external onlyTaxOffice returns (bool) {
        uint8 taxTiersRatesCount = uint8(taxTiersRates.length);
        require(_index < taxTiersRatesCount, "Index has to lower than count of tax tiers");
        require(_value <= 3000, "Tax equal or bigger to 30%");

        taxTiersRates[_index] = _value;
        emit SetTaxTiersRate(_index, _value);
        return true;
    }

    function setTaxRateAfterRebase(uint256 _value) external onlyTaxOffice returns (bool) {
        require(_value <= 3000, "Tax equal or bigger to 30%");
        emit SetTaxRateAfterRebase(taxRateAfterRebase, _value);
        taxRateAfterRebase = _value;
        return true;
    }

    function setTimeTaxAfterRebase(uint256 _value) external onlyTaxOffice returns (bool) {
        require(_value <= 24 hours, "Time equal or bigger to 24h");
        emit SetTimeTaxAfterRebase(timeTaxAfterRebase, _value);
        timeTaxAfterRebase = _value;
        return true;
    }

    function excludeTaxAddress(address _address) external onlyTaxOffice returns (bool) {
        require(!excludedTaxAddresses[_address], "Address can't be excluded");
        excludedTaxAddresses[_address] = true;
        return true;
    }

    function includeTaxAddress(address _address) external onlyTaxOffice returns (bool) {
        require(excludedTaxAddresses[_address], "Address can't be included");
        excludedTaxAddresses[_address] = false;
        return true;
    }

    function isAddressExcluded(address _address) external view returns (bool) {
        return _isExcluded[_address];
    }

    function enableCalculateTax() external onlyTaxOffice {
        enabledTax = true;
        emit EnableCalculateTax();
    }

    function disableCalculateTax() external onlyTaxOffice {
        enabledTax = false;
        emit DisableCalculateTax();
    }

    //Add new LP's for selling / buying fees
    function setMarketLpPairs(address _pair, bool _value) public onlyTaxOffice {
        marketLpPairs[_pair] = _value;
    }

}