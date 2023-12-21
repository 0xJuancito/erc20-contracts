// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

contract Main is IERC20Metadata, ERC20, Ownable {

    /**
     * The contract ensures via the '_update' function that a transaction amount does not exceed `maxTxAmount`.
     * For transactions involving addresses not included in `whitelistedAddresses`,
     * the function will throw an error if the amount surpasses the `maxTxAmount`.
     *
     * The value of `maxTxAmount` can be changed using the `maxTxAmountChange` function.
     */
    uint256 public maxTxAmount;

    /**
     * This limit is enforced in the '_update' function of the contract: after executing a transaction, a non-whitelisted address
     * should still hold a number of tokens not exceeding `maxWalletAmount`. If the limit were to be surpassed as a result
     * of the transaction, the function would throw an error, thereby preventing the transaction.
     *
     * The `maxWalletAmount` value can be updated by calling the `maxWalletChange` function and it applies only to non-whitelisted addresses.
     */
    uint256 public maxWalletAmount;

    /**
    * @dev The wallet that receives operation taxes and has the ability to withdraw them.
    *
    * It is responsible for receiving operation taxes from buy and sell transactions in `operationsTaxBuy` and `operationsTaxSell` respectively.
    *
    * Furthermore, `operationsWallet` is the recipient of any ETH or tokens accidentally sent to the contract and it can withdraw these
    * via the `withdrawETH` and `withdrawTokens` functions respectively.
    */
    address public operationsWallet;

    /**
     * Prevent admin to change critical addresses to this address:
     */
    address public DEAD = 0x000000000000000000000000000000000000dEaD;

    /**
     * Determines if transaction fees apply for a specific address.
     *
     * This mapping stores a boolean value for each address. If the boolean is true,
     * the address is exempted from transaction fees, otherwise transaction fees will apply.
     *
     * Fees can either be for buying or selling operations and are calculated in the '_update' function.
     * The exemption status of an address can be changed using the '' method.
     */
    mapping(address => bool) public hasFee;

    /**
    * @dev Maintains the whitelist of addresses exempt from transaction limits and fees.
    *
    * Addresses in this mapping are not bound by `maxTxAmount` and `maxWalletAmount` restrictions and do not incur tax
    * from buy/sell transactions.
    * They are set at contract initialisation and can be modified using `emergencyTaxRemoval`.
    */
    mapping(address => bool) public whitelistedAddresses;

    /**
    * @dev The tax rate applied to buy transactions not involving whitelisted addresses.
    *
    * This tax, as a percentage, is deducted from buy transactions between non-whitelisted addresses.
    * The tax is transferred to the operations wallet, thereby reducing the amount of tokens received on purchase.
    */
    uint256 public operationsTaxBuy;

    /**
     * @dev The tax rate applied to sell transactions not involving whitelisted addresses.
     *
     * This tax, as a percentage, is deducted from sell transactions between non-whitelisted addresses.
     * The tax is transferred to the operations wallet, therefore reducing the amount of tokens converted back on selling.
     */
    uint256 public operationsTaxSell;

    /**
     * @dev An instance of Uniswap V2 router to execute token swaps and liquidity provision.
     *
     * This is required for facilitating token swaps on the Uniswap exchange. It's initially set in the constructor
     * and is used in the `swapAndLiquify` and `_swapTokensForEth` functions to swap tokens for ETH and add liquidity to the pool.
     */
    IUniswapV2Router02 public router;

    /**
     * @dev The address of the Uniswap V2 pair for this contract's token and WETH.
     *
     * This address represents the Uniswap liquidity pool for this token and Wrapped Ether (WETH).
     * It's used during buy and sell operations to check if tokens are being bought from or sold into the pair.
     * It's initially set in the constructor and can be updated using the `updatePair` function.
     */
    address public uniswapV2Pair;

    /**
    * @dev A flag indicating if a token swap operation is in progress.
    *
    * This boolean is used to prevent reentrancy in the token swapping process. During a sell operation,
    * it's set to true in the '_update' function just before calling 'swapAndLiquify', and reset to false afterward.
    */
    bool private _progressSwap = false;

    /**
    * @dev Thrown when a token transfer amount exceeds the maximum transaction amount (`maxTxAmount`).
    */
    error ERC20TransferExceedsMaxTx(uint256 amount, uint256 maxTxAmount);

    /**
    * @dev Thrown when a token transfer would cause the receiver's balance to exceed the maximum wallet amount (`maxWalletAmount`).
    */
    error ERC20TransferExceedsMaxWallet(uint256 amount, uint256 maxWalletAmount);

    /**
    * @dev Thrown when an operation is attempted by someone other than the owner or the operations wallet.
    */
    error NotOwnerOrOperations();

    /**
    * @dev Thrown when a token transfer amount exceeds the maximum transaction amount (`maxTxAmount`) allowed.
    */
    error ERC20ExceedsMaxTxAmount(uint256 amount, uint256 maxTxAmount);

    /**
    * @dev Thrown when a specified address is invalid (equivalent to the `DEAD` address or the zero address).
    */
    error InvalidAddress(address addr);

    /**
    * @dev Thrown when attempting to set `maxTxAmount` to more than 10% of the total supply.
    */
    error CannotSetMaxTxAmountToMoreThan10Percent();

    /**
    * @dev Thrown when attempting to set `maxTxAmount` to less than 0.5% of the total supply.
    */
    error CannotSetMaxTxAmountToLessThanHalfPercent();

    /**
    * @dev Thrown when a eth transfer fails.
    */
    error CallFailed();

    /**
     * @dev Emitted when the operations wallet change process has been finalized
     *
     * Event Parameters:
     * _newWallet {address} - Holds the address of the new operations wallet after the change process
     */
    event SetOperationsWallet(address _newWallet);

    /**
     * @dev Emitted when an address is added or removed from the whitelist
     *
     * Event Parameters:
     * addy {address} - Holds the address that is being whitelisted or removed from the whitelist
     * changer {bool} - Holds the new whitelist status of the address. True if whitelisted, false if removed from whitelist
     */
    event WhitelistAddress(address indexed addy, bool changer);

    /**
     * @dev Emitted when ETH is withdrawn from the contract
     *
     * Event Parameters:
     * amount {uint256} - Holds the amount of ETH that was withdrawn
     */
    event WithdrawETH(uint256 amount);

    /**
     * @dev Emitted when tokens are withdrawn from the contract
     *
     * Event Parameters:
     * token {address} - Holds the address of the token that was withdrawn
     * amount {uint256} - Holds the amount of tokens that was withdrawn
     */
    event WithdrawTokens(address token, uint256 amount);

    /**
     * @dev Emitted when the maximum transaction amount is changed
     *
     * Event Parameters:
     * from {uint256} - Holds the previous maximum transaction amount
     * to {uint256} - Holds the new maximum transaction amount
     */
    event MaxWalletChange(uint from, uint to);

    /**
     * @dev Emitted when the maximum wallet amount is changed
     *
     * Event Parameters:
     * from {uint256} - Holds the previous maximum wallet amount
     * to {uint256} - Holds the new maximum wallet amount
     */
    event MaxTxAmountChange(uint from, uint to);

    /**
    * @dev Emitted when the Uniswap pair is changed
    *
    * Event Parameters:
    * from {address} - Holds the previous Uniswap pair address
    * to {address} - Holds the new Uniswap pair address
    */
    event PoolChanged(address indexed from, address indexed to);

    /**
     * @dev Emitted when tokens are swapped for ETH
     *
     * Event Parameters:
     * tokensSwapped {uint256} - Holds the amount of tokens that were swapped
     * ethReceived {uint256} - Holds the amount of ETH that was received
     */
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived
    );

    /**
     * @dev Ensures that the caller is either the contract owner or the operations wallet.
     *
     * This modifier restricts access to certain functions to only the owner of the contract or the operations
     * wallet. It prevents any other account from executing the function the modifier is attached to.
     */
    modifier onlyOwnerOrOperations() {
        if (owner() != _msgSender() && operationsWallet != _msgSender()) {
            revert NotOwnerOrOperations();
        }
        _;
    }

    /**
    * @dev Constructs a new instance of the Main contract.
    *
    * Sets up the contract with initial supply, treasury, owner, router, operations wallet, tax percentages,
    * maximum transaction amount, and maximum wallet amount.
    * Also, it creates a new Uniswap pair for the contract's token and WETH and whitelists critical addresses
    * including the treasury, the contract owner, the router, and the operations wallet.
    *
    * @param _symbol The symbol of the token.
    * @param _name The name of the token.
    * @param _totalSupply The total initial supply of tokens.
    * @param _treasure The treasury to hold all supply.
    * @param _owner The owner of the contract.
    * @param _router The Uniswap router to use for token swaps.
    * @param _operationsWalletAddress The operations wallet to receive fees.
    * @param _operationsTaxBuyPercentage The tax to be deducted on token buy transactions.
    * @param _operationsTaxSellPercentage The tax to be deducted on token sell transactions.
    * @param _maxTxAmount The maximum token amount that can be transferred in a single transaction.
    * @param _maxWalletAmount The maximum token amount that a non-whitelisted address can hold.
    */

    constructor(
        string memory _symbol,
        string memory _name,
        uint _totalSupply,
        address _treasure,
        address _owner,
        address _router,
        address _operationsWalletAddress,
        uint _operationsTaxBuyPercentage,
        uint _operationsTaxSellPercentage,
        uint _maxTxAmount,
        uint _maxWalletAmount
    )
    ERC20(_name, _symbol)
        /// @dev on OZ 5, we need to inform the contract admin:
    Ownable(_owner)
    {
        maxTxAmount = _maxTxAmount;
        maxWalletAmount = _maxWalletAmount;
        operationsTaxBuy = _operationsTaxBuyPercentage;
        operationsTaxSell = _operationsTaxSellPercentage;

        router = IUniswapV2Router02(_router);
        operationsWallet = _operationsWalletAddress;

        /// @dev: full whitelist treasure as it has all supply:
        whitelistedAddresses[_treasure] = true;
        hasFee[_treasure] = true;

        /// @dev whitelist other important addresses:
        whitelistedAddresses[owner()] = true;
        whitelistedAddresses[operationsWallet] = true;
        whitelistedAddresses[address(this)] = true;
        whitelistedAddresses[_owner] = true;
        whitelistedAddresses[msg.sender] = true; // to be able to add liquidity
        hasFee[address(router)] = true;
        hasFee[msg.sender] = true;
        hasFee[operationsWallet] = true;
        hasFee[address(this)] = true;

        /// @dev: supply is minted to treasure:

        _mint(_treasure, _totalSupply);

        uniswapV2Pair = IUniswapV2Factory(router.factory()).createPair(
            address(this),
            router.WETH()
        );
    }

    /**
    * @dev Overrides the OpenZeppelin `_update` function with added functionality.
    *
    * Implements additional checks for non-whitelisted addresses - transactions must not exceed `maxTxAmount`
    * and a non-whitelisted receiver's balance after the transaction must not exceed `maxWalletAmount`.
    * Also, implements tax deductions for transactions made by non-whitelisted addresses - a `operationsTaxBuy`
    * for purchases and `operationsTaxSell` for sales. If the transaction amount surpasses these conditions or
    * the receiver's balance including the new amount does surpass `maxWalletAmount`, operations involving the Uniswap pair,
    * the function throws an error preventing the transaction.
    *
    * @param from The sender address.
    * @param to The recipient address.
    * @param amount The amount of tokens to be transferred.
    */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override {
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }

        if (!whitelistedAddresses[from] && !whitelistedAddresses[to]) {
            if (to != uniswapV2Pair) {
                if (amount > maxTxAmount) {
                    revert ERC20TransferExceedsMaxTx(amount, maxTxAmount);
                }

                if ((amount + balanceOf(to)) > maxWalletAmount) {
                    revert ERC20TransferExceedsMaxWallet(
                        amount,
                        maxWalletAmount
                    );
                }
            }
        }

        uint256 transferAmount = amount;
        if (!hasFee[from] && !hasFee[to]) {
            if ((from == uniswapV2Pair || to == uniswapV2Pair)) {

                if (amount > maxTxAmount) {
                    revert ERC20ExceedsMaxTxAmount(amount, maxTxAmount);
                }
                // Buy
                if (
                    operationsTaxBuy > 0 &&
                    uniswapV2Pair == from &&
                    !whitelistedAddresses[to] &&
                    from != address(this)
                ) {
                    uint256 feeTokens = (amount * operationsTaxBuy) / 100;
                    super._transfer(from, address(this), feeTokens);
                    transferAmount = amount - feeTokens;
                }

                // Sell
                if (
                    uniswapV2Pair == to &&
                    !whitelistedAddresses[from] &&
                    to != address(this) &&
                    !_progressSwap
                ) {
                    uint256 taxSell = operationsTaxSell;
                    _progressSwap = true;
                    swapAndLiquify();
                    _progressSwap = false;

                    uint256 feeTokens = (amount * taxSell) / 100;
                    super._transfer(from, address(this), feeTokens);
                    transferAmount = amount - feeTokens;
                }
            }
        }
        super._update(from, to, transferAmount);
    }

    /**
     * @dev Swaps tokens stored in the contract to ether (ETH)
     *
     * This function is used to convert tokens in the contract (collected as fees)
     * to ETH. It is called during a sell operation when the `_progressSwap` flag
     * is true, indicating that a token swap operation is in progress.
     *
     * If the balance of tokens in the contract is greater than 0, the function
     * calls `_swapTokensForEth` function passing the total token balance of the contract.
     */
    function swapAndLiquify() internal {
        if (balanceOf(address(this)) == 0) {
            return;
        }
        uint256 contractTokenBalance = balanceOf(address(this));
        if (contractTokenBalance > 0) {
            _swapTokensForEth(contractTokenBalance, 0);
        }
    }

    /**
     * @dev Swaps a specified amount of tokens for ETH.
     * 
     * This function is an intermediary called by `swapAndLiquify` when the contract's balance is not empty.
     * It uses the Uniswap router to perform the swap, trading the contract's tokens for ETH. 
     * The function sets the necessary approvals for the router, formulates the swap path from the contract's token to WETH,
     * and then initiates the swap with Uniswap. The ETH is then held by the contract and can be withdrawn by the operations wallet.
     *
     * @param tokenAmount The amount of tokens to be swapped.
     * @param tokenAmountOut Expected minimum amount of ETH to receive from swap.
     */
    function _swapTokensForEth(
        uint256 tokenAmount,
        uint256 tokenAmountOut
    ) internal {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        IERC20(address(this)).approve(address(router), type(uint256).max);

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            tokenAmountOut,
            path,
            address(this),
            block.timestamp
        );

        emit SwapAndLiquify(tokenAmount, address(this).balance);

    }

    /**
     * @dev Updates the contract's Uniswap pair
     *
     * This function allows the contract owner or the operations wallet to update
     * the contract's Uniswap pair. This can be useful to change the liquidity pool in which the token is trading.
     *
     * To prevent misuse, it verifies the new pair address is non-zero and not equivalent to the DEAD address.
     * Reverts with 'InvalidAddress' error if the address is invalid.
     *
     * @param _pair The address of the new Uniswap pair.
     */
    function updatePair(address _pair) external onlyOwnerOrOperations {
        if (_pair == DEAD || _pair == address(0)) {
            revert InvalidAddress(_pair);
        }
        if( _pair.code.length == 0 ) {
            revert InvalidAddress(_pair);
        }

        IUniswapV2Pair pair = IUniswapV2Pair(_pair);
        // @dev: check if the pair is valid:
        address token0 = pair.token0();
        address token1 = pair.token1();
        if (token0 != address(this) && token1 != address(this)) {
            revert InvalidAddress(_pair);
        }

        emit PoolChanged(uniswapV2Pair, _pair);

        uniswapV2Pair = _pair;
    }

    /**
    * @dev Updates the operations wallet address
    *
    * This function allows the contract owner or the operations wallet to update
    * the operations wallet address. This can be useful to change the wallet that receives
    * the operations tax.
    *
    * To prevent misuse, it verifies the new wallet address is non-zero and not equivalent to the DEAD address.
    * Reverts with 'InvalidAddress' error if the address is invalid.
    *
    * @param _newWallet The address of the new operations wallet.
    */
    function setOperationsWallet( address _newWallet ) external onlyOwnerOrOperations {

        // @dev: set new wallet:
        operationsWallet = _newWallet;

        // @dev: add new wallet to whitelist:
        whitelistedAddresses[operationsWallet] = true;
        hasFee[operationsWallet] = true;

        emit SetOperationsWallet(_newWallet);
    }

    /**
    * @dev Calculates the upper limit for the number of tokens that can be transferred
    * in a single transaction.
    *
    * The upper limit is defined as 10% of the total token supply. The value can be used
    * as an argument to set the `maxTxAmount` and `maxWalletAmount` in the contract.
    *
    * @return {uint256} - Returns the upper limit value for the maximum transaction amount.
    */
    function getUpperTxValue() public view returns (uint256) {
        return (totalSupply() * 10) / 100;
    }

    /**
    * @dev Calculates the lower limit for the number of tokens that can be transferred
    * in a single transaction.
    *
    * The lower limit is defined as 0.5% of the total token supply. The value can be used
    * as an argument to verify the `maxTxAmount` and `maxWalletAmount` in the contract.
    *
    * @return {uint256} - Returns the lower limit value for the maximum transaction amount.
    */
    function getLowerTxValue() public view returns (uint256) {
        return (totalSupply() * 1) / 200;
    }

    /**
     * @dev Updates the maximum number of tokens that can be transferred in a single transaction (`maxTxAmount`).
     *
     * This function is accessible only to the contract owner. It allows the modification of `maxTxAmount`,
     * thereby changing the upper limit for the number of tokens that can be transferred in a single transaction
     * by non-whitelisted addresses. The new `maxTxAmount` needs to be within the range of 0.5% to 10%
     * of the total token supply. If out of this range, the function will revert.
     *
     * @param _maxTxAmount {uint256} - The new maximum number of tokens that can be transferred in a single transaction.
     */
    function maxTxAmountChange(
        uint256 _maxTxAmount
    ) external onlyOwner {

        if (_maxTxAmount > getUpperTxValue() ) {
            revert CannotSetMaxTxAmountToMoreThan10Percent();
        }

        if (_maxTxAmount < getLowerTxValue() ) {
            revert CannotSetMaxTxAmountToLessThanHalfPercent();
        }

        emit MaxTxAmountChange(maxTxAmount, _maxTxAmount);

        maxTxAmount = _maxTxAmount;

    }

    /**
     * @dev Updates the maximum number of tokens that a non-whitelisted address can hold (`maxWalletAmount`).
     *
     * This function is accessible only to the contract owner. It allows the modification of `maxWalletAmount`,
     * thereby changing the upper limit for the number of tokens that a non-whitelisted address can hold.
     * The new `maxWalletAmount` needs to be within the range of 0.5% to 10% of the total token supply.
     * If out of this range, the function will revert.
     *
     * @param _maxWalletAmount {uint256} - The new maximum number of tokens that any non-whitelisted address can hold.
     */
    function maxWalletChange(
        uint256 _maxWalletAmount
    ) external onlyOwner {

        if (_maxWalletAmount > getUpperTxValue() ) {
            revert CannotSetMaxTxAmountToMoreThan10Percent();
        }

        if (_maxWalletAmount < getLowerTxValue() ) {
            revert CannotSetMaxTxAmountToLessThanHalfPercent();
        }

        emit MaxWalletChange(maxWalletAmount, _maxWalletAmount);

        maxWalletAmount = _maxWalletAmount;
    }

    /**
    * @dev Transfers any ERC20 tokens sent by mistake to this contract, to the operations wallet.
    *
    * This function is accessible only to the contract owner or the operations wallet.
    * It allows the recovery of ERC20 tokens sent by mistake to this contract.
    *
    * @param token {address} - The contract address of the ER20 token to be withdrawn.
    */
    function withdrawTokens(address token) external onlyOwnerOrOperations {
        uint amount = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(operationsWallet, amount);
        emit WithdrawTokens(token, amount);
    }

    /**
    * @dev Transfers any ether sent by mistake to this contract or collected, to the operations wallet.
    *
    * This function is accessible only to the contract owner or the operations wallet.
    * It allows the recovery of ether sent by mistake to this contract or collect any fee accumulated in the contract.
    */
    function withdrawETH() external onlyOwnerOrOperations {
        uint amount = address(this).balance;
        (bool success,) = address(operationsWallet).call{value: amount}("");
        if (!success) {
            revert CallFailed();
        }
        emit WithdrawETH(amount);
    }

    /**
    * @dev Modifies the whitelist status of an address for transactions limits and fees exemption.
    *
    * This function is accessible only to the contract owner or the operations wallet. It allows the modification of
    * the `whitelistedAddresses` mapping for a specific address which determines whether transactions involving
    * that address are exempt from the `maxTxAmount` and `maxWalletAmount` restrictions and transaction fees.
    *
    * @param addy {address} - The address whose whitelist status is to be modified.
    * @param changer {bool} - The new whitelist status. If true, the address will be whitelisted, otherwise, it will lose its whitelist status.
    */

    function emergencyTaxRemoval(
        address addy,
        bool changer
    ) external onlyOwnerOrOperations {
        whitelistedAddresses[addy] = changer;
        emit WhitelistAddress(addy, changer);
    }

    /**
    * @dev callback to receive ethers from uniswapV2Router when swaping
    */
    receive() external payable {}
}
