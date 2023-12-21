// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {ISPEC} from "./ISPEC.sol";

/**
 * @title SPEC ERC20 token
 */
contract SPEC is ISPEC, Ownable {
    mapping(address => uint256) private _shares;
    mapping(address account => mapping(address spender => uint256))
        private _allowances;

    // Name and symbol of the ERC20 contract
    string private constant SYMBOL = "SPEC";
    string private constant NAME = "Speculate";
    // Maximum supply of SPEC tokens
    uint256 private constant MAX_SUPPLY = 100_000_000 * (10 ** 18);
    // Initial supply is 70M SPEC tokens
    uint256 private constant INITIAL_SUPPLY = 70_000_000 * (10 ** 18);
    // Every 60 days rebase amount gets halved
    uint256 private constant TIME_BETWEEN_REBASE_REDUCTION = 60 days;
    uint256 private constant REWARD_DENOMINATOR = 100000000000;

    // Total supply increases based when rebases happen
    uint256 private _totalSupply = INITIAL_SUPPLY;
    // Total share amount
    uint256 private immutable _totalShare =
        type(uint256).max - (type(uint256).max % INITIAL_SUPPLY);
    // Last time the rebase got halved
    uint256 private _lastRebaseReduction = 0;
    // Date of the next rebase, used to prevent rebasing too soon
    uint256 private _nextRebase = block.timestamp + 1 days;
    // Used to calculate the rebase amount
    uint256 private _reward = 357146000;
    // Address of the Uniswap V2 pool
    address public pool;
    // Percentage of trading fees on Uniswap
    // 600 means 6%
    uint256 public tradingFee = 600;
    // Addresses of the accounts that should not take rebase interest
    address[] public stableBalanceAddresses;
    // Address of the accounts that receive the trading fee
    address[3] public feeReceivers;

    /**
     * @notice Creates the token with the specified amount and sends all supply to the _recipient
     */
    constructor() Ownable(msg.sender) {
        _shares[msg.sender] = _totalShare;
    }

    /**
     * @notice Sets the trading fee percentage
     * @param _newTradingFee The new trading fee percentage
     */
    function setTradingFee(uint256 _newTradingFee) external onlyOwner {
        tradingFee = _newTradingFee;

        emit TradingFeeSet(_newTradingFee);
    }

    /**
     * @notice Sets the addresses of fee receivers
     * @param _feeReceivers Addresses of the 3 fee receivers
     */
    function setFeeReceivers(
        address[3] calldata _feeReceivers
    ) external onlyOwner {
        feeReceivers = _feeReceivers;

        emit FeeReceiversSet();
    }

    /**
     * @notice Sets the address of the Uniswap V2 pool
     * @param _pool Address of the Uniswap V2 pool
     */
    function setPoolAddress(address _pool) external onlyOwner {
        if (_pool == address(0x00)) {
            revert InvalidAddress();
        }

        pool = _pool;

        emit PoolAddressSet(_pool);
    }

    /**
     * @notice Adds an address to the stable addresses
     * @param _stableAddress The new address to add
     */
    function addStableAddress(address _stableAddress) external onlyOwner {
        address[] memory _stableBalanceAddresses = stableBalanceAddresses;

        if (pool == _stableAddress) {
            revert StableAddressCannotBePoolAddress(_stableAddress);
        }

        for (uint256 i = 0; i < _stableBalanceAddresses.length; ) {
            if (_stableBalanceAddresses[i] == _stableAddress) {
                revert StableAddressAlreadyExists(_stableAddress);
            }

            unchecked {
                ++i;
            }
        }

        stableBalanceAddresses.push(_stableAddress);

        emit StableBalanceAddressAdded(_stableAddress);
    }

    /**
     * @notice Removes an stable address from the list of stable addresses
     * @param _stableAddress The address to remove from the list
     */
    function removeStableAddress(address _stableAddress) external onlyOwner {
        address[] memory stableAddresses = stableBalanceAddresses;

        uint256 addressIndex = 0;
        uint256 addressFound = 1; // 1 = not found -- 2 = found

        // find the index of the _stableAddress
        for (uint256 i = 0; i < stableAddresses.length; ) {
            if (stableAddresses[i] == _stableAddress) {
                addressIndex = i;
                addressFound = 2;
            }

            unchecked {
                ++i;
            }
        }

        // revert if the _stableAddress does not exist in the list
        if (addressFound == 1) {
            revert StableAddressNotFound(_stableAddress);
        }

        // Move the last element into the place to delete
        stableBalanceAddresses[addressIndex] = stableBalanceAddresses[
            stableBalanceAddresses.length - 1
        ];

        // Remove the last element
        stableBalanceAddresses.pop();

        emit StableBalanceAddressRemoved(_stableAddress);
    }

    /**
     * @notice Returns true if the address is either the owner, stableAddress or feeReceiver
     * @param _holder The address to check
     * @return taxFree Returns whether if the holder is tax free or not
     */
    function isTaxFree(address _holder) public view returns (bool taxFree) {
        address[3] memory _feeReceivers = feeReceivers;
        address[] memory _stableBalanceAddresses = stableBalanceAddresses;

        taxFree = false;

        // Check the _holder between stable balance addresses
        for (uint256 i = 0; i < _stableBalanceAddresses.length; ) {
            if (_stableBalanceAddresses[i] == _holder) {
                taxFree = true;
            }

            unchecked {
                ++i;
            }
        }

        // Check the _holder between fee receivers
        for (uint256 i = 0; i < _feeReceivers.length; ) {
            if (_feeReceivers[i] == _holder) {
                taxFree = true;
            }

            unchecked {
                ++i;
            }
        }

        // Check the _holder with the owner
        if (owner() == _holder) {
            taxFree = true;
        }
    }

    /**
     * @notice Rebases and adds reward to the totalSupply
     */
    function rebase() external onlyOwner returns (uint256) {
        if (!_shouldRebase()) {
            revert RebaseNotAvailableNow();
        }

        if (_lastRebaseReduction == 0) {
            _lastRebaseReduction = block.timestamp;
        }

        // Checks if 60 days has passed. If so, then halves the rebase reward
        if (
            _lastRebaseReduction + TIME_BETWEEN_REBASE_REDUCTION <=
            block.timestamp
        ) {
            _reward -= (_reward * 50) / 100;

            _lastRebaseReduction = block.timestamp;
        }

        uint256 poolBalanceBefore = balanceOf(pool);
        (
            uint256 sumStableBalancesBefore,
            uint256[] memory stableBalancesBefore
        ) = _getStableAddressBalances();

        uint256 supplyDelta = (_totalSupply *
            _rewardCalculator(poolBalanceBefore + sumStableBalancesBefore)) /
            REWARD_DENOMINATOR;

        _nextRebase = _nextRebase + 1 days;
        _totalSupply = _totalSupply + supplyDelta;

        if (_totalSupply > MAX_SUPPLY) {
            _totalSupply = MAX_SUPPLY;
        }

        _fixStableBalances(poolBalanceBefore, stableBalancesBefore);

        emit Rebase(supplyDelta);

        return _totalSupply;
    }

    /**
     * @notice Returns the amount of shares per 1 balance amount
     * @return Returns the amount of shares per 1 balance amount
     */
    function sharePerBalance() public view returns (uint256) {
        return _totalShare / _totalSupply;
    }

    /**
     * @notice Calculates share amount to balance amount and returns it
     * @param _sharesAmount Amount of shares to convert
     * @return _balanceAmount Returns the balance amount relative to the share amount
     */
    function convertSharesToBalance(
        uint256 _sharesAmount
    ) public view returns (uint256 _balanceAmount) {
        _balanceAmount = _sharesAmount / sharePerBalance();
    }

    /**
     * @notice Calculates balance amount to share amount and returns it
     * @param _balanceAmount Amount of balance to convert
     * @return _sharesAmount Returns the share amount relative to the balance amount
     */
    function convertBalanceToShares(
        uint256 _balanceAmount
    ) public view returns (uint256 _sharesAmount) {
        _sharesAmount = _balanceAmount * sharePerBalance();
    }

    /**
     * @notice Returns the amount of tokens owned by `account`.
     * @param _account Address of the account
     * @return _balances Returns the amount of tokens owned by `account`.
     */
    function balanceOf(
        address _account
    ) public view returns (uint256 _balances) {
        _balances = convertSharesToBalance(_shares[_account]);
    }

    /**
     * @notice Returns the name of the token.
     * @return Returns the name of the token.
     */
    function name() public pure returns (string memory) {
        return NAME;
    }

    /**
     * @notice Returns the symbol of the token.
     * @return Returns the symbol of the token.
     */
    function symbol() public pure returns (string memory) {
        return SYMBOL;
    }

    /**
     * @notice Returns the decimals places of the token.
     * @return Returns the decimals places of the token.
     */
    function decimals() public pure returns (uint8) {
        return 18;
    }

    /**
     * @notice Returns the amount of tokens in existence.
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @notice Returns the remaining number of tokens that `spender` is allowed
     * @param _owner The owner of the tokens
     * @param _spender The spender of the owner's tokens
     * @return Returns the amount of allowance
     */
    function allowance(
        address _owner,
        address _spender
    ) public view returns (uint256) {
        return _allowances[_owner][_spender];
    }

    /**
     * @notice Sets `value` as the allowance of `spender` over the caller's tokens.
     * @param _spender The spender receiving the allowance
     * @param _value The amount of tokens being allowed
     * @return Returns true if the operation was successful
     */
    function approve(address _spender, uint256 _value) public returns (bool) {
        _approve(msg.sender, _spender, _value, true);

        return true;
    }

    /**
     * @notice Moves `value` tokens from the caller's account to `to`.
     * @param _to The address receiving the tokens
     * @param _value The amount of tokens being transferred
     * @return Returns true if the operation was successful
     */
    function transfer(address _to, uint256 _value) public returns (bool) {
        _transfer(msg.sender, _to, _value);

        return true;
    }

    /**
     * @notice Moves `value` tokens from `from` to `to` using the allowance mechanism.
     * @dev `value` is then deducted from the caller's allowance.
     * @param _from The address sending the tokens
     * @param _to The address receiving the tokens
     * @param _value The amount of tokens being transferred
     * @return Returns true if the operation was successful
     */
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public virtual returns (bool) {
        _spendAllowance(_from, msg.sender, _value);
        _transfer(_from, _to, _value);

        return true;
    }

    /**
     * @notice Calculates how much fee should be taken from the amount
     * @param _shareAmount Amount of shares that the receiver is going to receive
     */
    function _calculateFeeAmount(
        uint256 _shareAmount
    ) internal view returns (uint256) {
        return (_shareAmount / 10000) * tradingFee;
    }

    /**
     * @notice Calculates how much fee should be taken from a transfer
     * @param _from Address that is spending tokens
     * @param _to Address that is getting tokens
     * @param _shareAmount Share amount of the transfer
     * @return Fee of the transfer based on the sender and the receiver
     */
    function _calculateFee(
        address _from,
        address _to,
        uint256 _shareAmount
    ) internal view returns (uint256) {
        if (_from == pool || _to == pool) {
            if (isTaxFree(_from) || isTaxFree(_to)) {
                return 0;
            }

            return _calculateFeeAmount(_shareAmount);
        }

        return 0;
    }

    /**
     * @notice Spreads the fee between the 3 fee receivers
     * @param _fee The total amount of fee to spread
     */
    function _spreadFee(uint256 _fee) internal {
        address[3] memory _feeReceivers = feeReceivers;

        if (_fee == 0) {
            return;
        }

        for (uint256 i = 0; i < _feeReceivers.length; ) {
            _shares[_feeReceivers[i]] = _shares[_feeReceivers[i]] + (_fee / 3);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Returns true if 24 hours has passed since the last rebase
     * @return Returns true if 24 hours has passed since the last rebase
     */
    function _shouldRebase() internal view returns (bool) {
        return _nextRebase <= block.timestamp;
    }

    /**
     * @notice Accumulates the balances of stable addresses and returns the accumulated balance
     * and the array of the balances of stable balances
     * @return Returns the accumulated balance and the array of the balances of stable balances
     */
    function _getStableAddressBalances()
        internal
        view
        returns (uint256, uint256[] memory)
    {
        uint256[] memory fixedRebaseBalances = new uint256[](
            stableBalanceAddresses.length
        );
        uint256 sumBalances = 0;

        for (uint256 i = 0; i < fixedRebaseBalances.length; ) {
            uint256 accountBalance = balanceOf(stableBalanceAddresses[i]);

            sumBalances += accountBalance;
            fixedRebaseBalances[i] = accountBalance;

            unchecked {
                ++i;
            }
        }

        return (sumBalances, fixedRebaseBalances);
    }

    /**
     * @notice Sets back the balances of stable addresses to their balances before the rebase
     * @dev This is done because stable addresses and pool addresses should not take any rewards
     * @param _poolBalanceBefore Balance of Uniswap pool before the rebase
     * @param _stableBalancesBefore Balance of stable addresses before the rebase
     */
    function _fixStableBalances(
        uint256 _poolBalanceBefore,
        uint256[] memory _stableBalancesBefore
    ) internal {
        address[] memory _stableBalanceAddresses = stableBalanceAddresses;

        _shares[pool] = convertBalanceToShares(_poolBalanceBefore);

        for (uint256 i = 0; i < _stableBalanceAddresses.length; ) {
            _shares[_stableBalanceAddresses[i]] = convertBalanceToShares(
                _stableBalancesBefore[i]
            );

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Calculates the total reward amount
     * @param _poolAndStableAddressesBalances Total balance of stable addresses
     * @return totalReward Total reward amount
     */
    function _rewardCalculator(
        uint256 _poolAndStableAddressesBalances
    ) internal view returns (uint256 totalReward) {
        totalReward =
            (_reward * INITIAL_SUPPLY) /
            (totalSupply() - _poolAndStableAddressesBalances);
    }

    /**
     * @notice Moves a `value` amount of tokens from `from` to `to`.
     * @param _from The address sending the tokens
     * @param _to The address receiving the tokens
     * @param _value The amount of tokens being transferred
     */
    function _transfer(address _from, address _to, uint256 _value) internal {
        if (_from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }

        if (_to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }

        _update(_from, _to, _value);
    }

    /**
     * @notice Transfers a `value` amount of tokens from `from` to `to`
     * @param _from The address sending the tokens
     * @param _to The address receiving the tokens
     * @param _value The amount of tokens being transferred
     */
    function _update(
        address _from,
        address _to,
        uint256 _value
    ) internal virtual {
        uint256 shareAmount = convertBalanceToShares(_value);
        uint256 share = _shares[_from];

        if (share < shareAmount) {
            revert ERC20InsufficientBalance(_from, _value, 0);
        }

        _shares[_from] = _shares[_from] - shareAmount;

        uint256 fee = _calculateFee(_from, _to, shareAmount);

        _spreadFee(fee);

        _shares[_to] = _shares[_to] + (shareAmount - fee);

        emit Transfer(_from, _to, _value);
    }

    /**
     * @notice Updates `owner` s allowance for `spender` based on spent `value`.
     * @dev Does not update the allowance value in case of infinite allowance.
     * @param _owner The owner of the tokens
     * @param _spender The spender of the tokens
     * @param _value The value of the tokens being spent
     */
    function _spendAllowance(
        address _owner,
        address _spender,
        uint256 _value
    ) internal virtual {
        uint256 currentAllowance = allowance(_owner, _spender);

        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < _value) {
                revert ERC20InsufficientAllowance(
                    _spender,
                    currentAllowance,
                    _value
                );
            }

            _approve(_owner, _spender, currentAllowance - _value, false);
        }
    }

    /**
     * @notice Sets `value` as the allowance of `spender` over the owner
     * @param _owner The owner of the tokens
     * @param _spender The spender of the tokens
     * @param _value The total amount that owner wants to allow spender
     * @param _emitEvent Should this function emit events?
     */
    function _approve(
        address _owner,
        address _spender,
        uint256 _value,
        bool _emitEvent
    ) internal virtual {
        if (_owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }

        if (_spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }

        _allowances[_owner][_spender] = _value;

        if (_emitEvent) {
            emit Approval(_owner, _spender, _value);
        }
    }
}
