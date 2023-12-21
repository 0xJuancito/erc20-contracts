/**
 * @title Alpha Gardeners - The Ultimate Degen Trading Toolkit
 *
 *      Join us on Telegram: https://t.me/alphagardeners_lounge
 *      Follow us on Twitter: https://twitter.com/alpha_gardeners
 *
 */
// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "./Ownable.sol";
import "./Pausable.sol";
import "./IUniswap.sol";

contract AG is Ownable, Pausable {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    // ERC20 events.
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    // This token specific events.
    event BlacklistStatusUpdated(address wallet, bool isBlacklisted);
    event MarketPairUpdated(address pair, bool isMarketPair);
    event ExcludedFromFeesUpdated(address wallet, bool isExcluded);
    event TaxRecipientUpdated(address recipient);
    event TaxesUpdated(uint256 buyTax, uint256 sellTax, uint256 transferTax);
    event LimitsUpdated(uint256 maxBuy, uint256 maxSell, uint256 maxWallet);
    event NumTokensToSwapUpdated(uint256 amount);
    event ContractSwapEnabledUpdated(bool autoEnabled, bool manualEnabled);

    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    uint8 public constant decimals = 18;

    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    // No mint or burn means we can just use a constant.
    // Total supply must fit in uint128.
    uint256 public constant totalSupply = 8_000_000_000 * 10**decimals;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    /*//////////////////////////////////////////////////////////////
                              TOKEN-SPECIFIC
    //////////////////////////////////////////////////////////////*/

    address public taxRecipient;

    uint256 public numTokensToSwap = 2_500_000 * 10**decimals;
    bool public contractSwapEnabled = false;
    bool public manualSwapEnabled = false;
    bool private inSwap;

    IUniswapV2Router02 public uniswapV2Router;
    // IUniswapV2Pair public uniswapV2Pair;
    address private WETH;
    event UniswapRouterUpdated(address newRouter);

    // When accessing the buy tax, we also access buy limit, and the same applies for
    // sell tax and limit. We pack them into a struct to save on gas.
    struct taxAndLimit {
        uint128 tax;
        uint128 limit;
    }

    taxAndLimit public buyTaxAndLimit = taxAndLimit({
        tax: 0,
        limit: uint128(totalSupply)
    });
    taxAndLimit public sellTaxAndLimit = taxAndLimit({
        tax: 0,
        limit: uint128(totalSupply)
    });

    uint256 public transferTax = 0;
    uint256 public maxWallet = totalSupply;

    /// @dev totalSupply * maxTax cannot exceed uint256.
    /// @dev maxTax cannot exceed taxDenominator.
    uint256 private constant maxTax = 1_000; // 10%, same limit applies to all taxes.
    uint256 private constant taxDenominator = 10_000; // 500/10000 = 5%

    // Pack it into a struct instead of individual mappings to save on gas.
    struct walletState {
        bool isBlacklisted;
        bool isMarketPair;
        bool isExcludedFromFees;
    }
    mapping (address => walletState) public _walletState;

    /*//////////////////////////////////////////////////////////////
                            EIP-2612 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 internal immutable INITIAL_CHAIN_ID;

    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

    mapping(address => uint256) public nonces;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    // Start paused.
    constructor(
        string memory _name,
        string memory _symbol,
        address _taxRecipient,
        address routerAddress
    ) Ownable(msg.sender) Pausable(true) {
        // Require supply to be less than the max uint128 value.
        require(totalSupply < type(uint128).max, "TOTAL_SUPPLY_EXCEEDS_MAX");
        name = _name;
        symbol = _symbol;
        taxRecipient = _taxRecipient;

        // Setup the Uniswap router used for swapping fees.
        uniswapV2Router = IUniswapV2Router02(routerAddress);
        _approve(address(this), routerAddress, type(uint256).max);
        WETH = uniswapV2Router.WETH();

        // Setup for EIP-2612.
        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();

        // Exclude owner and the contract from fees.
        _walletState[msg.sender] = walletState({
            isBlacklisted: false,
            isMarketPair: false,
            isExcludedFromFees: true
        });
        emit ExcludedFromFeesUpdated(msg.sender, true);
        _walletState[address(this)] = walletState({
            isBlacklisted: false,
            isMarketPair: false,
            isExcludedFromFees: true
        });
        emit ExcludedFromFeesUpdated(address(this), true);

        // Mint the initial supply.
        unchecked {
            balanceOf[msg.sender] += totalSupply;
        }

        emit Transfer(address(0), msg.sender, totalSupply);
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, allowance[owner][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = msg.sender;
        uint256 currentAllowance = allowance[owner][spender];
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
    ) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        allowance[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }


    function transfer(address to, uint256 amount) public whenNotPaused returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public whenNotPaused returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "ERC20: insufficient allowance");
            // Won't overflow since allowed >= amount.
            unchecked {
                allowance[from][msg.sender] = allowed - amount;
            }
        }

        _transfer(from, to, amount);

        return true;
    }

    function _buyTransfer(address to, uint256 amount) internal view returns (uint256) {
        // balanceOf[to]+amount can't exceed uint256 as it can't exceed totalSupply.
        // Taxes are capped at 10k and totalSupply is <= uint(128).max, overflow is impossible.
        unchecked {
            taxAndLimit memory buyConfig = buyTaxAndLimit;
            uint256 fees = (amount * buyConfig.tax) / taxDenominator;

            require(amount <= buyConfig.limit, "transfer exceeds max buy");
            require(balanceOf[to] + amount <= maxWallet, "balance exceeds max wallet");

            return fees;
        }
    }

    function _sellTransfer(uint256 amount) internal view returns (uint256) {
        unchecked {
            taxAndLimit memory sellConfig = sellTaxAndLimit;
            uint256 fees = (amount * sellConfig.tax) / taxDenominator;

            require(amount <= sellConfig.limit, "transfer exceeds max sell");
            // Do not check max wallet as market pairs are allowed to exceed it.

            return fees;
        }
    }

    function _baseTransfer(address to, uint256 amount) internal view returns (uint256) {
        unchecked {
            require(balanceOf[to] + amount <= maxWallet, "balance exceeds max wallet");

            return (amount * transferTax) / taxDenominator;
        }
    }

    function _swapTokens() internal {
        // Only try to swap fees during a sell transaction.
        uint256 numTokens = numTokensToSwap;
        bool overMinTokenBalance = balanceOf[address(this)] >= numTokens;
        if (
            overMinTokenBalance &&
            !inSwap &&
            contractSwapEnabled
        ) {
            // Try to swap the fees and send them to the tax recipient.
            // If this fails, still allow the transfer to go through.
            try this.swapFeesAndSend(numTokens, 0) {} catch {}
        }
    }

    function _calcFees(address to, uint256 amount, bool isBuy, bool isSell) internal view returns (uint256) {
        if(isBuy) {
            return _buyTransfer(to, amount);
        }
        if(isSell) {
            return _sellTransfer(amount);
        }
        return _baseTransfer(to, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 balance = balanceOf[from];
        require(balance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            balanceOf[from] = balance - amount;
        }

        walletState memory fromWalletState = _walletState[from];
        walletState memory toWalletState = _walletState[to];

        // Don't allow blacklisted wallets to receive or send tokens.
        require(!fromWalletState.isBlacklisted && !toWalletState.isBlacklisted, "blacklisted");

        uint256 fees = 0;
        bool takeFee = !fromWalletState.isExcludedFromFees && !toWalletState.isExcludedFromFees;

        // Tax and enforce limits appriopriately.
        if(takeFee) {
            bool isBuy = fromWalletState.isMarketPair;
            bool isSell = toWalletState.isMarketPair;

            fees = _calcFees(to, amount, isBuy, isSell);

            if(isSell && !isBuy) {
                _swapTokens();
            }
        }

        // Add the amount minus fees to the receiver.
        uint256 amountMinusFees;
        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        // fees is less than amount, so it can't overflow.
        unchecked {
            amountMinusFees = amount - fees;
            balanceOf[to] += amountMinusFees;
        }
        emit Transfer(from, to, amountMinusFees);

        // Add any fees collected to the contract.
        if(fees > 0) {
            emit Transfer(from, address(this), fees);
            unchecked {
                balanceOf[address(this)] += fees;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                               SWAP LOGIC
    //////////////////////////////////////////////////////////////*/

    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

    function swapFeesAndSend(uint256 tokenAmount, uint256 minOut) external lockTheSwap {
        if(msg.sender != address(this)) {
            require(manualSwapEnabled || msg.sender == owner(), "manual swap disabled");
        }

        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WETH;

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            minOut,
            path,
            taxRecipient, // Send ETH directly to the tax recipient.
            block.timestamp
        );
    }

    /*//////////////////////////////////////////////////////////////
                             OWNER-ONLY
    //////////////////////////////////////////////////////////////*/

    function setBlacklisted(address account, bool value) external onlyOwner {
        require(account != address(this), "cant change contract");
        _walletState[account].isBlacklisted = value;
        emit BlacklistStatusUpdated(account, value);
    }

    function setMarketPair(address account, bool value) external onlyOwner {
        require(account != address(this), "cant change contract");
        _walletState[account].isMarketPair = value;
        emit MarketPairUpdated(account, value);
    }

    function setExcludedFromFees(address account, bool value) external onlyOwner {
        require(account != address(this), "cant change contract");
        _walletState[account].isExcludedFromFees = value;
        emit ExcludedFromFeesUpdated(account, value);
    }

    function setTaxRecipient(address account) external onlyOwner {
        taxRecipient = account;
        emit TaxRecipientUpdated(account);
    }

    function setTaxes(uint256 _buyTax, uint256 _sellTax, uint256 _transferTax) public onlyOwner {
        // Cap any of the taxes to 10% max.
        require(_buyTax <= maxTax, "buy is too high");
        require(_sellTax <= maxTax, "sell is too high");
        require(_transferTax <= maxTax, "transfer is too high");

        buyTaxAndLimit.tax = uint128(_buyTax);
        sellTaxAndLimit.tax = uint128(_sellTax);
        transferTax = _transferTax;

        emit TaxesUpdated(_buyTax, _sellTax, _transferTax);
    }

    // setLimits are in wad of tokens. 1e18 = 1 token.
    function setLimits(uint256 _maxBuyWad, uint256 _maxSellWad, uint256 _maxWalletWad) public onlyOwner {
        require(_maxBuyWad >= 20_000_000, "buy is too low");
        require(_maxSellWad >= 20_000_000, "sell is too low");
        require(_maxWalletWad >= 20_000_000, "wallet is too low");

        buyTaxAndLimit.limit = uint128(_maxBuyWad * 10**decimals);
        sellTaxAndLimit.limit = uint128(_maxSellWad * 10**decimals);
        maxWallet = _maxWalletWad * 10**decimals;

        emit LimitsUpdated(_maxBuyWad * 10**decimals, _maxSellWad * 10**decimals, _maxWalletWad * 10**decimals);
    }

    // setNumTokensToSwap is in wad of tokens. 1e18 = 1 token.
    function setNumTokensToSwap(uint256 amountWad) external onlyOwner {
        require(amountWad > 0, "amount cant be zero");
        numTokensToSwap = amountWad * 10**decimals;

        emit NumTokensToSwapUpdated(amountWad * 10**decimals);
    }

    function setContractSwapEnabled(bool _contractSwapEnabled, bool _manualSwapEnabled) public onlyOwner {
        contractSwapEnabled = _contractSwapEnabled;
        manualSwapEnabled = _manualSwapEnabled;
        emit ContractSwapEnabledUpdated(_contractSwapEnabled, _manualSwapEnabled);
    }

    function Unpause() external onlyOwner {
        _unpause();
    }

    function Pause() external onlyOwner {
        _pause();
    }

    function updateUniswapRouter(address newRouter) external onlyOwner {
        address oldRouterAddress = address(uniswapV2Router);
        require(oldRouterAddress != newRouter, "can't set the same router address");

        uniswapV2Router = IUniswapV2Router02(newRouter);
        WETH = uniswapV2Router.WETH();

        // Approve the new router to spend contract's tokens.
        _approve(address(this), newRouter, type(uint256).max);

        // Reset approval on old router.
        _approve(address(this), oldRouterAddress, 0);

        emit UniswapRouterUpdated(newRouter);
    }

    function openTrading() external onlyOwner {
        // Start with manual swap disabled.
        setContractSwapEnabled(true, false);
        setLimits(
            20_000_000,
            20_000_000,
            60_000_000
        );
        setTaxes(1000, 1000, 0);
        _unpause();
    }

    function skimETH(address to, uint256 amount) external onlyOwner {
        (bool success,) = to.call{value: amount}("");
        require(success, "ETH transfer failed");
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TRANSFER_FAILED');
    }

    function skimTokens(address tokenAddress, address to, uint256 amount) external onlyOwner {
        safeTransfer(tokenAddress, to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                             PAUSABLE OVERRIDES
    //////////////////////////////////////////////////////////////*/

    // Override the requireNotPaused implementation to allow the owner
    // to interact with the contract while it is paused. This allows the
    // owner to airdrop tokens or add liquidity while in a paused state.
    function _requireNotPaused() internal view override{
        if(paused()) {
            if(tx.origin != owner() && msg.sender != owner()) {
                revert EnforcedPause();
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             EIP-2612 LOGIC
    //////////////////////////////////////////////////////////////*/

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                                ),
                                owner,
                                spender,
                                value,
                                nonces[owner]++,
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            require(recoveredAddress != address(0) && recoveredAddress == owner, "INVALID_SIGNER");

            allowance[recoveredAddress][spender] = value;
        }

        emit Approval(owner, spender, value);
    }

    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes(name)),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }
}
