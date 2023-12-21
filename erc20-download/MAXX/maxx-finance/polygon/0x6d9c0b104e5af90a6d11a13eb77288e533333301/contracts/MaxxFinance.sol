// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/// Account is blocked from transferring tokens
error AccountBlocked();

/// Transfer exceeds the whale limit
error WhaleLimit();

/// Transfer exceeds the daily sell limit
error DailyLimit();

/// New value is out of bounds for consumer protection
error ConsumerProtection();

/// The Maxx Vault address has already been initialized or attempting to set to the zero address
error InitializationFailed();

/// MinTransferTax must be <= MaxTransferTax
error InvalidTax();

/// MinTaxAmount must be <= MaxTaxAmount
error InvalidTaxAmount();

error ZeroAddress();

/// @title Maxx Finance -- MAXX ERC20 token contract
/// @author Alta Web3 Labs - SonOfMosiah
contract MaxxFinance is ERC20, ERC20Burnable, AccessControl, Pausable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice The amount of MAXX tokens burned
    uint256 public burnedAmount;

    /// @notice Deployment timestamp for this contract
    uint256 public immutable initialTimestamp;

    /// @notice Maxx Finance Vault address
    address public maxxVault;

    /// @notice block limited or not
    bool public isBlockLimited;

    /// @notice Global daily sell limit
    uint256 public globalDailySellLimit;

    /// @notice Whale limit
    uint256 public whaleLimit;

    /// @notice The number of blocks required
    uint256 public blocksBetweenTransfers;

    /// @notice Max tax rate when calling transfer() or transferFrom()
    uint16 public maxTransferTax; // 1000 = 10%
    /// @notice Min tax rate when calling transfer() or transferFrom()
    uint16 public minTransferTax; // 1000 = 10%

    /// @notice Threshold for the maximum tax rate
    uint256 public maxTaxAmount;
    /// @notice Ceiling amount qualified for the minimum tax rate
    uint256 public minTaxAmount;

    uint64 public constant GLOBAL_DAILY_SELL_LIMIT_MINIMUM = 1e9; // 1 billion
    uint64 public constant WHALE_LIMIT_MINIMUM = 1e6; // 1 million
    uint8 public constant BLOCKS_BETWEEN_TRANSFERS_MAXIMUM = 5;
    uint16 public constant TRANSFER_TAX_FACTOR = 1e4;
    uint64 public constant INITIAL_SUPPLY = 1e11;

    /// @notice blacklisted addresses
    mapping(address => bool) public isBlocked;

    /// @notice whitelisted addresses
    mapping(address => bool) public isAllowed;

    /// @notice tax exempt addresses
    mapping(address => bool) public isTaxExempt;

    /// @notice The block number of the address's last purchase from a pool
    mapping(address => uint256) public lastPurchase;

    /// @notice Whether the address is a Maxx token pool or not
    mapping(address => bool) public isPool;

    /// @notice The amount of tokens sold each day
    mapping(uint32 => uint256) public dailyAmountSold;

    event PoolAdded(address indexed pool);
    event PoolRemoved(address indexed pool);
    event MinTransferTaxUpdated(uint16 minTransferTax);
    event MaxTransferTaxUpdated(uint16 maxTransferTax);
    event MinTaxAmountUpdated(uint256 minTaxAmount);
    event MaxTaxAmountUpdated(uint256 maxTaxAmount);
    event BlocksBetweenTransfersUpdated(uint256 blocksBetweenTransfers);
    event BlockLimitedUpdated(bool blockLimited);
    event AddressAllowed(address indexed account);
    event AddressDisallowed(address indexed account);
    event AddressBlocked(address indexed account);
    event AddressUnblocked(address indexed account);
    event GlobalDailySellLimitUpdated(uint256 globalDailySellLimit);
    event WhaleLimitUpdated(uint256 whaleLimit);
    event TaxExemptAdded(address indexed account);
    event TaxExemptRemoved(address indexed account);

    constructor() ERC20("Maxx Finance", "MAXX") {
        _grantRole(DEFAULT_ADMIN_ROLE, tx.origin);
        initialTimestamp = block.timestamp;
    }

    function init(
        address _vault,
        uint16 _transferTax,
        uint256 _whaleLimit,
        uint256 _globalSellLimit
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (maxxVault != address(0) || _vault == address(0)) {
            revert InitializationFailed();
        }
        maxxVault = _vault;
        _mint(maxxVault, INITIAL_SUPPLY * 10**decimals()); // Initial supply: 100 billion MAXX
        setMaxTransferTax(_transferTax);
        setMinTransferTax(_transferTax);
        setWhaleLimit(_whaleLimit);
        setGlobalDailySellLimit(_globalSellLimit);
    }

    /// @notice Mints tokens
    /// @dev Increases the token balance of `_to` by `amount`
    /// @param _to The address to mint to
    /// @param _amount The amount to mint
    function mint(address _to, uint256 _amount)
        external
        whenNotPaused
        onlyRole(MINTER_ROLE)
    {
        _mint(_to, _amount);
    }

    /// @notice identify an address as a liquidity pool
    /// @param _pool The pool address
    function addPool(address _pool) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_pool == address(0)) {
            revert ZeroAddress();
        }
        isPool[_pool] = true;
        isAllowed[_pool] = true;
        emit PoolAdded(_pool);
    }

    /// @notice Remove an address from the pool list
    /// @param _pool The pool address
    function removePool(address _pool) external onlyRole(DEFAULT_ADMIN_ROLE) {
        isPool[_pool] = false;
        isAllowed[_pool] = false;
        emit PoolRemoved(_pool);
    }

    /// @notice Set the blocks required between transfers
    /// @param _blocksBetweenTransfers The number of blocks required between transfers
    function setBlocksBetweenTransfers(uint256 _blocksBetweenTransfers)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (_blocksBetweenTransfers > BLOCKS_BETWEEN_TRANSFERS_MAXIMUM) {
            revert ConsumerProtection();
        }
        blocksBetweenTransfers = _blocksBetweenTransfers;
        emit BlocksBetweenTransfersUpdated(_blocksBetweenTransfers);
    }

    /// @notice Update blockLimited
    /// @param _blockLimited Whether to block limit or not
    function updateBlockLimited(bool _blockLimited)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        isBlockLimited = _blockLimited;
        emit BlockLimitedUpdated(_blockLimited);
    }

    /// @notice add an address to the allowlist
    /// @param _address The address to add to the allowlist
    function allow(address _address) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_address == address(0)) {
            revert ZeroAddress();
        }
        isAllowed[_address] = true;
        emit AddressAllowed(_address);
    }

    /// @notice remove an address from the allowlist
    /// @param _address The address to remove from the allowlist
    function disallow(address _address) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_address == address(0)) {
            revert ZeroAddress();
        }
        isAllowed[_address] = false;
        emit AddressDisallowed(_address);
    }

    /// @notice add an address to the blocklist
    /// @dev "block" is a reserved symbol in Solidity, so we use "blockUser" instead
    /// @param _address The address to add to the blocklist
    function blockUser(address _address) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_address == address(0)) {
            revert ZeroAddress();
        }
        isBlocked[_address] = true;
        emit AddressBlocked(_address);
    }

    /// @notice remove an address from the blocklist
    /// @param _address The address to remove from the blocklist
    function unblock(address _address) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_address == address(0)) {
            revert ZeroAddress();
        }
        isBlocked[_address] = false;
        emit AddressUnblocked(_address);
    }

    /// @notice Pause the contract
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /// @notice Unpause the contract
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /// @notice Add an address to the tax exempt list
    /// @param _exempt The address to add to the tax exempt list
    function addTaxExempt(address _exempt)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        isTaxExempt[_exempt] = true;
        emit TaxExemptAdded(_exempt);
    }

    /// @notice Remove an address from the tax exempt list
    /// @param _exempt The address to remove from the tax exempt list
    function removeTaxExempt(address _exempt)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        isTaxExempt[_exempt] = false;
        emit TaxExemptRemoved(_exempt);
    }

    /// @notice Get the timestamp of the next day when the daily amount sold will be reset
    /// @return timestamp The timestamp corresponding to the next day when the global daily sell limit will be reset
    function getNextDayTimestamp() external view returns (uint256 timestamp) {
        uint256 day = uint256(getCurrentDay() + 1);
        timestamp = initialTimestamp + (day * 1 days);
    }

    /// @notice Set the min transfer tax percentage
    /// @dev Set minTransferTax to maxTransferTax for a flat tax
    /// @param _minTransferTax The minimum transfer tax to set
    function setMinTransferTax(uint16 _minTransferTax)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (_minTransferTax > maxTransferTax) {
            revert InvalidTax();
        }
        if (_minTransferTax > 2000 || _minTransferTax > maxTransferTax) {
            revert ConsumerProtection();
        }
        minTransferTax = _minTransferTax;
        emit MinTransferTaxUpdated(_minTransferTax);
    }

    /// @notice Set the max transfer tax percentage
    /// @dev Set maxTransferTax to minTransferTax for a flat tax
    /// @param _maxTransferTax The transfer tax to set
    function setMaxTransferTax(uint16 _maxTransferTax)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (_maxTransferTax < minTransferTax) {
            revert InvalidTax();
        }
        if (_maxTransferTax > 2000) {
            revert ConsumerProtection();
        }
        maxTransferTax = _maxTransferTax;
        emit MaxTransferTaxUpdated(_maxTransferTax);
    }

    /// @notice Set the min tax amount
    /// @param _minTaxAmount The minimum tax amount to set
    function setMinTaxAmount(uint256 _minTaxAmount)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (_minTaxAmount > maxTaxAmount) {
            revert InvalidTaxAmount();
        }
        minTaxAmount = _minTaxAmount;
        emit MinTaxAmountUpdated(_minTaxAmount);
    }

    /// @notice Set the max tax amount
    /// @param _maxTaxAmount The max tax amount to set
    function setMaxTaxAmount(uint256 _maxTaxAmount)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (_maxTaxAmount < minTaxAmount) {
            revert InvalidTaxAmount();
        }
        maxTaxAmount = _maxTaxAmount;
        emit MaxTaxAmountUpdated(_maxTaxAmount);
    }

    /// @dev Overrides the transfer() function and implements a transfer tax on lp pools
    /// @param _to The address to transfer to
    /// @param _amount The amount to transfer
    /// @return Whether the transfer was successful
    function transfer(address _to, uint256 _amount)
        public
        override
        whenNotPaused
        returns (bool)
    {
        // Wallet is blacklisted if they attempt to buy and then sell in the same block or consecutive blocks
        if (
            isBlockLimited &&
            isPool[_to] &&
            !isAllowed[msg.sender] &&
            lastPurchase[msg.sender] >= block.number - blocksBetweenTransfers
        ) {
            isBlocked[msg.sender] = true;
            return false;
        }

        if (
            (isPool[_to] || isPool[msg.sender]) &&
            (!isTaxExempt[msg.sender] && !isTaxExempt[_to])
        ) {
            uint256 tax = _getTaxAmount(_amount);
            _amount -= tax;
            require(super.transfer(maxxVault, tax / 2));
            burn(tax / 2);
        }
        return super.transfer(_to, _amount);
    }

    /// @dev Overrides the transferFrom() function and implements a transfer tax on lp pools
    /// @param _from The address to transfer from
    /// @param _to The address to transfer to
    /// @param _amount The amount to transfer
    /// @return Whether the transfer was successful
    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) public override whenNotPaused returns (bool) {
        // Wallet is blacklisted if they attempt to buy and then sell in the same block or consecutive blocks
        if (
            isBlockLimited &&
            isPool[_to] &&
            !isAllowed[_from] &&
            lastPurchase[_from] >= block.number - blocksBetweenTransfers
        ) {
            isBlocked[_from] = true;
            return false;
        }

        if (
            (isPool[_from] || isPool[_to]) &&
            (!isTaxExempt[_from] && !isTaxExempt[_to])
        ) {
            uint256 tax = _getTaxAmount(_amount);
            _amount -= tax;
            require(super.transferFrom(_from, maxxVault, tax / 2));
            burnFrom(_from, tax / 2);
        }
        return super.transferFrom(_from, _to, _amount);
    }

    /// @notice Set the global daily sell limit
    /// @param _globalDailySellLimit The new global daily sell limit
    function setGlobalDailySellLimit(uint256 _globalDailySellLimit)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (_globalDailySellLimit < GLOBAL_DAILY_SELL_LIMIT_MINIMUM) {
            revert ConsumerProtection();
        }
        globalDailySellLimit = _globalDailySellLimit * 10**decimals();
        emit GlobalDailySellLimitUpdated(_globalDailySellLimit);
    }

    /// @notice Set the whale limit
    /// @param _whaleLimit The new whale limit
    function setWhaleLimit(uint256 _whaleLimit)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (_whaleLimit < WHALE_LIMIT_MINIMUM) {
            revert ConsumerProtection();
        }
        whaleLimit = _whaleLimit * 10**decimals();
        emit WhaleLimitUpdated(_whaleLimit);
    }

    /// @notice This functions gets the current day since the initial timestamp
    /// @return day The current day since launch
    function getCurrentDay() public view returns (uint32 day) {
        day = uint32((block.timestamp - initialTimestamp) / 1 days);
        return day;
    }

    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal virtual override(ERC20) {
        bool allowed = isAllowed[_from];
        if ((isBlocked[_to] || isBlocked[_from]) && !allowed) {
            // can't send or receive tokens if the address is blocked
            revert AccountBlocked();
        }

        if (_to == address(0)) {
            // burn | burnFrom
            burnedAmount += _amount; // Burned amount is added to the total burned amount
        }

        if (_from != address(0) && _to != address(0)) {
            // transfer | transferFrom
            if (isPool[_from]) {
                // Also occurs if user is withdrawing their liquidity tokens.
                lastPurchase[_to] = block.number;
            } else if (isPool[_to]) {
                if (_amount > whaleLimit && !allowed) {
                    revert WhaleLimit();
                }

                uint32 day = getCurrentDay();
                dailyAmountSold[day] += _amount;
                if (dailyAmountSold[day] > globalDailySellLimit && !allowed) {
                    revert DailyLimit();
                }
            }
        }

        super._beforeTokenTransfer(_from, _to, _amount);
    }

    function _getTaxAmount(uint256 _amount)
        internal
        view
        returns (uint256 tax)
    {
        uint256 netAmount;

        if (_amount < minTaxAmount) {
            netAmount =
                (_amount * (TRANSFER_TAX_FACTOR - minTransferTax)) /
                TRANSFER_TAX_FACTOR;
        } else if (_amount > maxTaxAmount) {
            netAmount =
                (_amount * (TRANSFER_TAX_FACTOR - maxTransferTax)) /
                TRANSFER_TAX_FACTOR;
        } else {
            uint256 amountDiff = maxTaxAmount - minTaxAmount;
            uint256 taxDiff = maxTransferTax - minTransferTax;
            uint256 dynamicPoint = _amount - minTaxAmount;
            uint256 dynamicTransferTax = minTaxAmount +
                (dynamicPoint * taxDiff) /
                amountDiff;
            netAmount =
                (_amount * (TRANSFER_TAX_FACTOR - dynamicTransferTax)) /
                TRANSFER_TAX_FACTOR;
        }
        tax = _amount - netAmount;
        return tax;
    }
}
