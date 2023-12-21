// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./GPOStructs.sol";

/**
____________________________
Description:
GoldPesa Option Contract (GPO) - 1 GPO represents the option to purchase 1 GPX at spot gold price + 1 %.
__________________________________
*/

abstract contract BaseGPO is ERC20Permit, Pausable, Ownable, GPOStructs {
    
    /// @notice Token Name
    string public constant _name = "GPO";
    /// @notice Token Symbol
    string public constant _symbol = "GoldPesa Option";
    /// @notice GPO Hard Cap
    uint256 public constant fixedSupply = 100_000_000;
    /// @notice GPO Cap on Wallet
    uint256 public capOnWallet = 100_000;
    /// @notice GoldPesa fee on swap percentage
    uint256 public feeOnSwap = 10;
    /// @notice USDC ERC20 token Address
    address public addrUSDC;
    /// @dev Uniswap V3 pool fee * 10000 = 1 %
    uint24 internal swapPoolFee = 10000;
    /// @notice Uniswap V3 GPO/USDC liquidity pool address
    address public authorizedPool;
    /// @notice When freeTrade is true the token bypasses the hard cap on wallet and can be traded freely on any exchange.
    bool public freeTrade = false;
    /// @notice The feeOnSwap percentage is distributed to the addresses and their respective percentage which are held in the feeSplits array
    FeeSplit[] public feeSplits;
    /// @notice Keeps a record of the number of addresses in the feeSplits array 
    uint256 public feeSplitsLength;

    /**
     * @notice Mapping which holds details of the wallet addresses which can bypass the wallet hard cap and the custom GoldPesa SwapRouter.
     */
    mapping(address => bool) public whitelistedWallets;

    /// @notice Enables and disables the GoldPesa custom SwapRouter.
    bool public swapEnabled = false;

    /**
     * @dev Initializes the contract and mints the GPO Hard Cap which is also the total fixed supply.
     * 
     * @notice WhiteLists 0x0 address as well as the GPO contract address itself.
     */
    constructor() ERC20(_symbol, _name) ERC20Permit(_name) {
        whitelistedWallets[address(0x0)] = true;
        whitelistedWallets[address(this)] = true;

        _mint(address(this), hardCapOnToken());
    }

    /**
     * @dev GPO Owner can manually transfer GPO tokens from the GPO contract to another wallet address.
     *
     * @param _to: Destination address
     * @param amount: Total amount * 10**18 
     */ 
    function transferTokensTo(address _to, uint256 amount) external onlyOwner {
        _transfer(address(this), _to, amount);
        emit ReserveTokenTransfer(_to, amount);
    }
    
    /**
     * @dev GPO owner can manually add or remove wallet addresses from the whitelistedWallets mapping.
     *
     * @param _addr: wallet/contract address
     * @param yesOrNo: True = Whitelisted - False = Not Whitelisted
     */ 
    function changeWalletWhitelist(address _addr, bool yesOrNo) external onlyOwner {
        whitelistedWallets[_addr] = yesOrNo;
        emit WalletWhitelistChanged(_addr, yesOrNo);
    }

    /**
     * @dev GPO owner can set the state of the contract to "freeTrade".
     */ 
    function switchFreeTrade() external onlyOwner {
        freeTrade = !freeTrade;
        emit FreeTradeChanged(freeTrade);
    }

    /**
     * @dev GPO owner can enable/disable swap functions.
     */ 
    function switchSwapEnabled() external onlyOwner {
        swapEnabled = !swapEnabled;
        emit SwapPermChanged(swapEnabled);
    }

    /**
     * @dev GPO owner can set the feeOnSwap percentage.
     *
     * Note: feeOnSwap can never be greater than 10%
     */ 
    function setFeeOnSwap(uint24 _feeOnSwap) external onlyOwner {
        require(_feeOnSwap <= 10, "feeOnSwap cannot be greater than 10 percent");
        feeOnSwap = _feeOnSwap;
        emit FeeOnSwapChanged(_feeOnSwap);
    }

    /**
     * @dev GPO owner can set the "feeOnSwap" distribution details.
     *
     * Note: Total feeSplits must add upto 100%
     */ 
    function setFeeSplits(FeeSplit[] memory _feeSplits) external onlyOwner {
        uint256 grandTotal = 0;
        for (uint256 i = 0; i < _feeSplits.length; i++) {
            FeeSplit memory f = _feeSplits[i];
            grandTotal += f.fee;
        }
        require(grandTotal == 100);
        delete feeSplits;
        for (uint256 i = 0; i < _feeSplits.length; i++) {
            feeSplits.push(_feeSplits[i]);
        }
        feeSplitsLength = _feeSplits.length;
        emit FeeSplitsChanged(feeSplitsLength, feeSplits);
    }

    /**
     * @dev Distributes the feeOnSwap amount collected during any swap transaction to the addresses defined in the "feeSplits" array.
     *
     * Note: Total feeSplits must add upto 100%
     */ 
    function distributeFee(uint256 amount) internal {
        uint256 grandTotal = 0;
        for (uint256 i = 0; i < feeSplits.length; i++) {
            FeeSplit storage f = feeSplits[i];
            uint256 distributeAmount = amount * f.fee / 100;
            TransferHelper.safeTransfer(addrUSDC, f.recipient, distributeAmount);
            grandTotal += distributeAmount;
        }
        if (grandTotal != amount && feeSplits.length > 0) {
            FeeSplit storage f = feeSplits[0];
            TransferHelper.safeTransfer(addrUSDC, f.recipient, amount - grandTotal);
        }
    }

    /// @notice Additional requirements before transferring tokens.
    function _beforeTokenTransferAdditional(address from, address to, uint256 amount) internal virtual;

    /**
     * @dev Defines the rules that must be satisfied before GPO can be transferred.
     */ 
    function _beforeTokenTransfer(
        address from, 
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        // Ensures that GPO token holders cannot burn their own tokens, unless they are whitelisted.
        require(to != address(0x0) || whitelistedWallets[from], "GPO_ERR: Cannot burn");
        // Unless "freeTrade" has been enabled this require statement rejects any transfers to wallets which will break the wallet hard cap unless the 
        // receiving wallet address is a "whitelistedWallet".
        require(
            freeTrade || 
            from == address(0x0) ||
            whitelistedWallets[to] || 
            balanceOf(to) + amount <= hardCapOnWallet(),
            "GPO_ERR: Hard cap on wallet reached" 
        );

        _beforeTokenTransferAdditional(from, to, amount);
        // Disables all GPO transfers if the token has been paused by GoldPesa.
        require(!paused(), "ERC20Pausable: token transfers paused");
    }

    /**
     * @return uint256 GPO token hard cap ("fixedSupply") in wei.
     */ 
    function hardCapOnToken() public virtual view returns (uint256) {
        return fixedSupply * (10**(uint256(decimals())));
    }

    /**
     * @return uint256 GPO token wallet hard cap ("capOnWallet") in wei.
     */ 
    function hardCapOnWallet() public view returns (uint256) {
        return capOnWallet * (10**(uint256(decimals())));
    }
    
    /**
     * @return uint256 GoldPesa feeOnSwap in USDC which is used in the swap functions.
     */ 
    function calculateFeeOnSwap(uint256 amount) internal view returns (uint256)
    {
        return amount * feeOnSwap / 100;
    }
    
    /**
     * @dev GPO Owner can pause GPO token transfers.
     */ 
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev GPO Owner can unpause GPO token transfers.
     */ 
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Burn function utilized by GoldPesa DEX when users exercise their GPO and purchase GPX.
     *
     * @param amount GPO Amount * 10**18
     */ 
    function burn(uint256 amount) external {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, deducting from the caller's allowance.
     *
     * @param account Account to burn GPO tokens from
     * @param amount GPO Amount * 10**18
     *
     * NOTE: The caller must have allowance for `accounts`'s tokens of at least `amount`.
     */
    function burnFrom(address account, uint256 amount) external {
        _spendAllowance(account, _msgSender(), amount);
        _burn(account, amount);
    }

    /**
     * @dev GPO Owner can change the authorized pool address when required.
     *
     * @param pool New Uniswap pool address
     * @param fee New Uniswap V3 pool fee * 10000
     */ 
    function unsafeSetAuthorizedPool(address pool, uint24 fee) external onlyOwner {
        whitelistedWallets[authorizedPool] = false;
        authorizedPool = pool;
        whitelistedWallets[authorizedPool] = true;
        swapPoolFee = fee;
        emit PoolParametersChanged(authorizedPool, fee);
    }

    /**
     * @dev GPO Owner can set the capOnWallet amount.
     *
     * @param _capOnWallet Max GPO tokens allowed per wallet
     */ 
    function setCapOnWallet(uint256 _capOnWallet) external onlyOwner {
        capOnWallet = _capOnWallet;
        emit CapOnWalletChanged(_capOnWallet);
    }
}