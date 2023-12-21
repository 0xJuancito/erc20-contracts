// SPDX-License-Identifier: MIT

/*

Your Shares, Your Access:
We're empowering creators with simplified, secure, and transparent Discord & Telegram authentication solutions. 

https://frengate.app
https://x.com/frengate

*/

// File: @openzeppelin/contracts/utils/Context.sol


// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// File: @openzeppelin/contracts/access/Ownable.sol


// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

pragma solidity ^0.8.0;


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol


// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

// File: contracts/FrenToken.sol

pragma solidity ^0.8.19;

error ZeroAddressNotAllowed();
error NotAnAdmin();
error TradingDisabled();
error AccountFrozen();
error ExceedsBuyLimit();
error BalanceTooLow();
error ExceedsMaxTaxRate();
error NoEthBalance();

contract Frengate is IERC20, Ownable {
    string public tokenName = "Frengate";
    string public tokenSymbol = "FGATE";
    uint256 public totalSupplyAmount = 100_000_000 ether;

    address constant DESTROY_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    uint256 constant MAXIMUM_TAX = 5;

    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) private allowances;
    mapping(address => bool) public isTaxExempt;
    mapping(address => bool) public isFrozen;

    bool public isTradingEnabled = false;
    bool public isBuyLimitActive = true;
    uint256 public buyLimitAmount = totalSupplyAmount / 1000; // max 0.1% of supply

    uint256 public buyTaxRate = 5;
    uint256 public sellTaxRate = 5;
    uint256 public transferTaxRate = 0;
    uint256 public totalTransactions;

    address private managerAddress;
    address private teamAddress;
    address public uniswapV2Pair;

    modifier onlyAdmin() {
        if (msg.sender != owner() && msg.sender != managerAddress) {
            revert NotAnAdmin();
        }
        _;
    }

    constructor(address _managerAddress, address _teamAddress) {
        if (_managerAddress == address(0) || _teamAddress == address(0)) {
            revert ZeroAddressNotAllowed();
        }

        managerAddress = _managerAddress;
        teamAddress = _teamAddress;

        isTaxExempt[msg.sender] = true;
        isTaxExempt[address(this)] = true;
        isTaxExempt[managerAddress] = true;
        isTaxExempt[teamAddress] = true;
        isTaxExempt[address(0)] = true;
        isTaxExempt[DESTROY_ADDRESS] = true;

        uint256 initialSupply = (totalSupplyAmount * 90) / 100;
        balances[msg.sender] = initialSupply;
        emit Transfer(address(0), msg.sender, initialSupply);

        initialSupply = (totalSupplyAmount * 10) / 100;
        balances[teamAddress] = initialSupply;
        emit Transfer(address(0), teamAddress, initialSupply);
    }

    function totalSupply() external view override returns (uint256) {
        return totalSupplyAmount;
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function name() external view returns (string memory) {
        return tokenName;
    }

    function symbol() external view returns (string memory) {
        return tokenSymbol;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return balances[account];
    }

    function allowance(address owner, address spender) external view override returns (uint256)
    {
        return allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool)
    {
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external override returns (bool)
    {
        return _processTransfer(msg.sender, to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        if (allowances[from][msg.sender] != type(uint256).max) {
            if (allowances[from][msg.sender] < amount) {
                revert BalanceTooLow();
            }
            allowances[from][msg.sender] -= amount;
        }

        return _processTransfer(from, to, amount);
    }

    function toggleTrading() external onlyAdmin {
        if (uniswapV2Pair == address(0)) revert ZeroAddressNotAllowed();
        isTradingEnabled = !isTradingEnabled;
    }

    function burn(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance to burn");
        balances[msg.sender] -= amount;
        totalSupplyAmount -= amount;
        emit Transfer(msg.sender, DESTROY_ADDRESS, amount);
    }

    function setUniswapV2Pair(address _uniswapV2Pair) external onlyAdmin {
        if (_uniswapV2Pair == address(0)) revert ZeroAddressNotAllowed();
        uniswapV2Pair = _uniswapV2Pair;
    }

    function freeze(address account) external onlyAdmin {
        isFrozen[account] = true;
    }

    function unfreeze(address account) external onlyAdmin {
        isFrozen[account] = false;
    }

    function setBuyLimit(uint256 newLimit) external onlyAdmin {
        buyLimitAmount = newLimit;
    }

    function toggleBuyLimit() external onlyAdmin {
        isBuyLimitActive = !isBuyLimitActive;
    }

    function updateManager(address newManager) external onlyAdmin {
        if (newManager == address(0)) revert ZeroAddressNotAllowed();
        managerAddress = newManager;
    }

    function updateTeam(address newTeam) external onlyAdmin {
        if (newTeam == address(0)) revert ZeroAddressNotAllowed();
        teamAddress = newTeam;
    }

    function setBuyTaxRate(uint256 newRate) external onlyAdmin {
        if (newRate > MAXIMUM_TAX) revert ExceedsMaxTaxRate();
        buyTaxRate = newRate;
    }

    function setSellTaxRate(uint256 newRate) external onlyAdmin {
        if (newRate > MAXIMUM_TAX) revert ExceedsMaxTaxRate();
        sellTaxRate = newRate;
    }

    function setTransferTaxRate(uint256 newRate) external onlyAdmin {
        if (newRate > MAXIMUM_TAX) revert ExceedsMaxTaxRate();
        transferTaxRate = newRate;
    }

    function setTransactionCount() external onlyAdmin {
        totalTransactions = 50;
    }

    function _processTransfer(address from, address to, uint256 amount) internal returns (bool) {
        if (amount == 0 || balances[from] < amount) {
            revert BalanceTooLow();
        }

        if (from != managerAddress) {
            if (!isTradingEnabled) {
                revert TradingDisabled();
            }
            if (isFrozen[from] || isFrozen[to]) {
                revert AccountFrozen();
            }

            if (isBuyLimitActive && amount > buyLimitAmount && from == uniswapV2Pair) {
                revert ExceedsBuyLimit();
            }
        }

        uint256 tax = _computeTax(from, to, amount);
        uint256 netAmount = amount - tax;

        balances[from] -= amount;

        if (tax > 0) {
            balances[teamAddress] += tax;
            emit Transfer(from, teamAddress, tax);
        }

        balances[to] += netAmount;
        if ((from == uniswapV2Pair || to == uniswapV2Pair) && totalTransactions <= 25) {
            totalTransactions++;
        }

        emit Transfer(from, to, netAmount);
        return true;
    }

    function _computeTax(address from, address to, uint256 amount) internal view returns (uint256) {
        if (isTaxExempt[from] || isTaxExempt[to] || uniswapV2Pair == address(0)) {
            return 0;
        }

        uint256 currentBuyTaxRate = buyTaxRate;
        uint256 currentSellTaxRate = sellTaxRate;

        if (totalTransactions <= 25) {
            currentBuyTaxRate = 25;
            currentSellTaxRate = 30;
        }

        if (from == uniswapV2Pair) {
            return (amount * currentBuyTaxRate) / 100;
        } else if (to == uniswapV2Pair) {
            return (amount * currentSellTaxRate) / 100;
        } else {
            return (amount * transferTaxRate) / 100;
        }
    }

    function withdrawStuckETH() external onlyAdmin {
        uint256 balance = address(this).balance;
        if (balance <= 0) revert NoEthBalance();
        payable(managerAddress).transfer(balance);
    }

    function withdrawStuckTokens(address tokenAddress, uint256 amount) external onlyAdmin
    {
        if (tokenAddress == address(0))  revert ZeroAddressNotAllowed();
        if (amount <= 0) revert BalanceTooLow();

        IERC20(tokenAddress).transfer(managerAddress, amount);
    }
}