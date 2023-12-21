/*

Website : ItsaBanger.io 
Telegram : https://t.me/ItsABanger_Portal

*/


pragma solidity 0.8.20;

// SPDX-License-Identifier: MIT

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

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
}

interface IERC20Metadata is IERC20{
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() external virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

library Address {
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}

library SafeERC20 {
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }
}

interface ILpPair {
    function sync() external;
    function mint(address to) external returns (uint liquidity);
}

interface IDexRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function swapExactTokensForETHSupportingFeeOnTransferTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IDexFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}

contract Banger is ERC20, Ownable {

    mapping (address => bool) public exemptFromFees;
    mapping (address => bool) public exemptFromLimits;

    mapping (address => bool) public isAMMPair;

    address public marketingAddress;
    address public devAddress;
    address public bangerAddress;

    Taxes public buyTax;
    Taxes public sellTax;

    TokensForTax public tokensForTax;

    bool public limited = true;

    uint256 public swapTokensAtAmt;

    address public lpPair;
    IDexRouter internal dexRouter;
    IWETH internal immutable WETH;

    mapping(address => uint256) private _holderLastTransferBlock; // to hold last Transfers temporarily during launch
    bool public transferDelayEnabled = true;
    mapping(uint256 => mapping(uint256 => uint256)) public gweiMapping;

    TxLimits public txLimits;

    uint64 public constant FEE_DIVISOR = 10000;

    // structs

    struct TxLimits {
        uint128 transactionLimit;
        uint128 walletLimit;
    }

    struct Taxes {
        uint48 marketingTax;
        uint48 devTax;
        uint48 bangerTax;
        uint48 totalTax;
    }

    struct TokensForTax {
        uint64 tokensForMarketing;
        uint64 tokensForDev;
        uint64 tokensForBanger;
        bool gasSaver;
    }

    uint256 public launchTime;
    bool public dynamicTaxOn;

    // events

    event UpdatedTransactionLimit(uint newMax);
    event UpdatedWalletLimit(uint newMax);
    event SetExemptFromFees(address _address, bool _isExempt);
    event SetExemptFromLimits(address _address, bool _isExempt);
    event RemovedLimits();
    event UpdatedBuyTax(uint newAmt);
    event UpdatedSellTax(uint newAmt);

    // constructor

    constructor()
        ERC20("BANGER", "BANGER")
    {   
        address _v2Router;

        // @dev assumes WETH pair
        if(block.chainid == 1){
            _v2Router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
        } else if(block.chainid == 5){
            _v2Router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
        } else {
            revert("Chain not configured");
        }

        dynamicTaxOn = true;

        dexRouter = IDexRouter(_v2Router);

        marketingAddress = 0xDfA81Dbd6822E3a50147586fFD11870B5d67cB74;
        devAddress = 0xBa7cc9CFAee71eaC953e702cB014fa05B53E428a;
        bangerAddress = 0x9FF044C9A4F9Bc834b9e308c80e22C4c470DE1d4;

        uint256 _totalSupply = 5 * 1e9 * 1e18;
        _mint(address(this), 4_250_000_000 * 1e18);
        _mint(msg.sender, _totalSupply - balanceOf(address(this)));

        txLimits.transactionLimit = uint128(totalSupply() * 5 / 1000);
        txLimits.walletLimit = uint128(totalSupply() * 1 / 100);
        swapTokensAtAmt = totalSupply() * 25 / 100000;

        buyTax.marketingTax = 700;
        buyTax.devTax = 700;
        buyTax.bangerTax = 600;
        buyTax.totalTax = buyTax.marketingTax + buyTax.devTax + buyTax.bangerTax;

        sellTax.marketingTax = 700;
        sellTax.devTax = 700; 
        sellTax.bangerTax = 600;
        sellTax.totalTax = sellTax.marketingTax + sellTax.devTax + sellTax.bangerTax;

        tokensForTax.gasSaver = true;

        WETH = IWETH(dexRouter.WETH());
        lpPair = IDexFactory(dexRouter.factory()).createPair(address(this), address(WETH));

        isAMMPair[lpPair] = true;

        exemptFromLimits[lpPair] = true;
        exemptFromLimits[msg.sender] = true;
        exemptFromLimits[address(this)] = true;
        exemptFromLimits[marketingAddress] = true;

        exemptFromFees[msg.sender] = true;
        exemptFromFees[address(this)] = true;
        exemptFromFees[marketingAddress] = true;
 
        _approve(address(this), address(dexRouter), type(uint256).max);
        _approve(address(msg.sender), address(dexRouter), totalSupply());
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        
        if(!exemptFromFees[from] && !exemptFromFees[to]){
            if(limited){
                checkLimits(from, to, amount);
            }
            amount -= handleTax(from, to, amount);
        }

        super._transfer(from,to,amount);
    }

    function checkLimits(address from, address to, uint256 amount) internal {
        bool exFromLimitsTo = exemptFromLimits[to];
        uint256 balanceOfTo = balanceOf(to);
        TxLimits memory _txLimits = txLimits;
        // buy
        if (isAMMPair[from] && !exFromLimitsTo) {
            require(amount <= _txLimits.transactionLimit, "Max Txn");
            require(amount + balanceOfTo <= _txLimits.walletLimit, "Max Wallet");
        } 
        // sell
        else if (isAMMPair[to] && !exemptFromLimits[from]) {
            require(amount <= _txLimits.transactionLimit, "Max Txn");
        }
        else if(!exFromLimitsTo) {
            require(amount + balanceOfTo <= _txLimits.walletLimit, "Max Wallet");
        }

        if (transferDelayEnabled){
            if (to != address(dexRouter) && to != address(lpPair)){
                require(_holderLastTransferBlock[tx.origin] < block.number, "Transfer Delay enabled");
                require(tx.origin == to, "no buying to external wallets yet");
                _holderLastTransferBlock[tx.origin] = block.number;
                if(launchTime + 45 >= block.timestamp){
                    require(gweiMapping[tx.gasprice][amount] < block.number, "Dupe Txn");
                    gweiMapping[tx.gasprice][amount] = block.number;
                }
            }
        }
    }

    function handleTax(address from, address to, uint256 amount) internal returns (uint256){

        if(balanceOf(address(this)) >= swapTokensAtAmt && !isAMMPair[from]) {
            convertTaxes();
        }

        if(dynamicTaxOn){
            setInternalTaxes();
        }
        
        uint128 tax = 0;

        Taxes memory taxes;

        if (isAMMPair[to]){
            taxes = sellTax;
        } else if(isAMMPair[from]){
            taxes = buyTax;
        }

        if(taxes.totalTax > 0){
            TokensForTax memory tokensForTaxUpdate = tokensForTax;
            tax = uint128(amount * taxes.totalTax / FEE_DIVISOR);
            tokensForTaxUpdate.tokensForMarketing += uint64(tax * taxes.marketingTax / taxes.totalTax / 1e9);
            tokensForTaxUpdate.tokensForDev += uint64(tax * taxes.devTax / taxes.totalTax / 1e9);
            tokensForTaxUpdate.tokensForBanger += uint64(tax * taxes.bangerTax / taxes.totalTax / 1e9);
            tokensForTax = tokensForTaxUpdate;
            super._transfer(from, address(this), tax);
        }
        
        return tax;
    }

    function swapTokensForETH(uint256 tokenAmt) private {

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = address(WETH);

        dexRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmt,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function convertTaxes() private {

        uint256 contractBalance = balanceOf(address(this));
        TokensForTax memory tokensForTaxMem = tokensForTax;
        uint256 totalTokensToSwap = tokensForTaxMem.tokensForMarketing + tokensForTaxMem.tokensForDev + tokensForTaxMem.tokensForBanger;
        
        if(contractBalance == 0 || totalTokensToSwap == 0) {return;}

        if(contractBalance > swapTokensAtAmt * 40){
            contractBalance = swapTokensAtAmt * 40;
        }
        if(contractBalance > 0){

            swapTokensForETH(contractBalance);
            
            uint256 ethBalance = address(this).balance;

            bool success;

            if(tokensForTaxMem.tokensForDev > 0){
                (success,) = devAddress.call{value: ethBalance * tokensForTaxMem.tokensForDev/ totalTokensToSwap}("");  
            }

            if(tokensForTaxMem.tokensForBanger > 0){
                (success,) = bangerAddress.call{value: ethBalance * tokensForTaxMem.tokensForBanger/ totalTokensToSwap}("");  
            }

            ethBalance = address(this).balance;

            if(ethBalance > 0){
                (success,) = marketingAddress.call{value: ethBalance}("");  
            }
        }

        tokensForTaxMem.tokensForMarketing = 0;
        tokensForTaxMem.tokensForDev = 0;
        tokensForTaxMem.tokensForBanger = 0;
        tokensForTax = tokensForTaxMem;
    }

    // owner functions
    function setExemptFromFee(address _address, bool _isExempt) external onlyOwner {
        require(_address != address(0), "Zero Address");
        require(_address != address(this), "Cannot unexempt contract");
        exemptFromFees[_address] = _isExempt;
        emit SetExemptFromFees(_address, _isExempt);
    }

    function setExemptFromLimit(address _address, bool _isExempt) external onlyOwner {
        require(_address != address(0), "Zero Address");
        if(!_isExempt){
            require(_address != lpPair, "Cannot remove pair");
        }
        exemptFromLimits[_address] = _isExempt;
        emit SetExemptFromLimits(_address, _isExempt);
    }

    function updateTransactionLimit(uint128 newNumInTokens) external onlyOwner {
        require(newNumInTokens >= (totalSupply() * 5 / 1000)/(10**decimals()), "Too low");
        txLimits.transactionLimit = uint128(newNumInTokens * (10**decimals()));
        emit UpdatedTransactionLimit(txLimits.transactionLimit);
    }

    function updateWalletLimit(uint128 newNumInTokens) external onlyOwner {
        require(newNumInTokens >= (totalSupply() * 1 / 100)/(10**decimals()), "Too low");
        txLimits.walletLimit = uint128(newNumInTokens * (10**decimals()));
        emit UpdatedWalletLimit(txLimits.walletLimit);
    }

    function updateSwapTokensAmt(uint256 newAmount) external onlyOwner {
        require(newAmount >= (totalSupply() * 1) / 100000, "Swap amount cannot be lower than 0.001% total supply.");
        require(newAmount <= (totalSupply() * 5) / 1000, "Swap amount cannot be higher than 0.5% total supply.");
        swapTokensAtAmt = newAmount;
    }

    function updateBuyTax(uint48 _marketingTax, uint48 _devTax, uint48 _bangerTax) external onlyOwner {
        Taxes memory taxes;
        taxes.marketingTax = _marketingTax;
        taxes.devTax = _devTax;
        taxes.bangerTax = _bangerTax;
        taxes.totalTax = _marketingTax + _devTax + _bangerTax;
        require(taxes.totalTax  <= 300, "Keep tax at or below 3%");
        emit UpdatedBuyTax(taxes.totalTax);
        buyTax = taxes;
    }

    function updateSellTax(uint48 _marketingTax, uint48 _devTax, uint48 _bangerTax) external onlyOwner {
        Taxes memory taxes;
        taxes.marketingTax = _marketingTax;
        taxes.devTax = _devTax;
        taxes.bangerTax = _bangerTax;
        taxes.totalTax = _marketingTax + _devTax + _bangerTax;
        require(taxes.totalTax  <= 300, "Keep tax at or below 3%");
        emit UpdatedSellTax(taxes.totalTax);
        sellTax = taxes;
    }

    function removeTransferDelay() external onlyOwner {
        require(transferDelayEnabled, "Already disabled");
        transferDelayEnabled = false;
    }

    function removeDynamicTax() external onlyOwner {
        require(dynamicTaxOn, "Already disabled");
        dynamicTaxOn = false;
    }

    function removeLimits() external onlyOwner {
        limited = false;
        transferDelayEnabled = false;
        TxLimits memory _txLimits;
        uint256 supply = totalSupply();
        _txLimits.transactionLimit = uint128(supply);
        _txLimits.walletLimit = uint128(supply);
        txLimits = _txLimits;
        emit RemovedLimits();
    }

    function airdropToWallets(address[] calldata wallets, uint256[] calldata amountsInWei) external onlyOwner {
        require(wallets.length == amountsInWei.length, "arrays length mismatch");
        for(uint256 i = 0; i < wallets.length; i++){
            super._transfer(msg.sender, wallets[i], amountsInWei[i]);
        }
    }

    function rescueTokens(address _token, address _to) external onlyOwner {
        require(_token != address(0), "_token address cannot be 0");
        require(_token != address(this), "_token address cannot be native token");
        uint256 _contractBalance = IERC20(_token).balanceOf(address(this));
        SafeERC20.safeTransfer(IERC20(_token),_to, _contractBalance);
    }

    function updateMarketingAddress(address _address) external onlyOwner {
        require(_address != address(0), "zero address");
        marketingAddress = _address;
    }

    function updateDevAddress(address _address) external onlyOwner {
        require(_address != address(0), "zero address");
        devAddress = _address;
    }

    function updateBangerAddress(address _address) external onlyOwner {
        require(_address != address(0), "zero address");
        bangerAddress = _address;
    }

    function setInternalTaxes() internal {
        Taxes memory newBuyTax = buyTax;
        Taxes memory newSellTax = sellTax;
        uint256 currentTime = block.timestamp;
        uint256 timeSinceLaunch = currentTime - launchTime;
        if(timeSinceLaunch >= 30 minutes){
            dynamicTaxOn = false;

            newBuyTax.marketingTax = 100;
            newBuyTax.devTax = 100;
            newBuyTax.bangerTax = 100;
            newBuyTax.totalTax = 300;

            newSellTax.marketingTax = 100;
            newSellTax.devTax = 100;
            newSellTax.bangerTax = 100;
            newSellTax.totalTax = 300;

        } else if (timeSinceLaunch >= 10 minutes){
            newBuyTax.marketingTax = 400;
            newBuyTax.devTax = 300;
            newBuyTax.bangerTax = 300;
            newBuyTax.totalTax = 1000;

            newSellTax.marketingTax = 400;
            newSellTax.devTax = 300;
            newSellTax.bangerTax = 300;
            newSellTax.totalTax = 1000;

        }

        if(buyTax.totalTax != newBuyTax.totalTax){
            buyTax = newBuyTax;
        }
        if(sellTax.totalTax != newSellTax.totalTax){
            sellTax = newSellTax;
        }
    }

    receive() payable external {}

    function addLp(address _to) external onlyOwner payable {
        require(address(this).balance > 0 && balanceOf(address(this)) > 0);

        WETH.deposit{value: address(this).balance}();

        super._transfer(address(this), address(lpPair), balanceOf(address(this)));
        IERC20(address(WETH)).transfer(address(lpPair), IERC20(address(WETH)).balanceOf(address(this)));
        ILpPair(lpPair).mint(_to);
        launchTime = block.timestamp;
    }
}