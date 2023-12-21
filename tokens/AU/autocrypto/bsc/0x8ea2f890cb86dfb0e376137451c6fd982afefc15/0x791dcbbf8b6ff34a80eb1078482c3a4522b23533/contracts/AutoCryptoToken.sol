/**
 * Website: autocrypto.ai
 * International Telegram: t.me/AutoCryptoInternational
 * Spanish Telegram: t.me/AutoCryptoSpain
 * Starred Calls Telegram: t.me/AutoCryptoStarredCalls
 * Discord: discord.gg/autocrypto
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/IAccessControlUpgradeable.sol";

/**
 * @notice Interface for AutoCrypto presales contracts. {releaseToken} will gather the contributed BNB.
*/
interface Presale {
    function releaseToken() external;
    function getContributors() external returns (address[] memory, uint[] memory);
}
/**
 * @notice Interface for AutoCrypto Firewall contract used to avoid bots at launch.
*/
interface Firewall {
    function defender(address, address, bool) external view returns (bool);
    function liquidityAdded() external;
}

/**
 * @notice Interface for WBNB contract used to provide liquidity at {releaseToken} function.
*/
interface IWBNB {
    function deposit() external payable;
    function transfer(address dst, uint wad) external;
    function balanceOf(address account) external view returns (uint);
}

/**
 * @notice Interface for Pancakeswap Liquidity Pair used to provide liquidity at {releaseToken} function.
*/
interface IPancakePair {
    function sync() external;
}

/**
 * @notice Interface for Pancakeswap Factory used to create a liquidity pair at {initialize} function.
*/
interface IPancakeFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

/**
 * @notice Interface for Pancakeswap Router used to provide liquidity at {releaseToken} function
 * and fetch Pancakeswap Factory address and WBNB address.
*/
interface IPancakeRouter02 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

/**
 * @notice Interface for AutoCrypto App used to manage users' data.
*/ 
interface IAutoCryptoApp {
    struct UserData {
        uint8 tierOwned;
        uint userIndex;
        uint lastSellDate;
        uint allowedToSell;
        uint penaltyAppTimestamp;
        bool revertSellOverLimit;
        uint vestedAmount;
        uint initialVestingDate;
    }
    function getUserData(address user) external view returns (UserData memory);
    function canSellOverLimit(address user) external view returns (bool);
    function updateUserData(address user, uint amount, bool selling) external;
    function hasPenalty(address user) external view returns (bool);
    function balanceWithVesting(address user) external view returns (uint);
}

/**
 * @title AutoCrypto Token
 * @author AutoCrypto
 * @notice ERC20 contract created for AutoCrypto token using custom fees and anti-bot system. 
 *
 * It will be deployed through a proxy contract to provide updates if needed.
 * The contract is managed through a Timelock contract, which is managed through
 * a gnosis safe to provide security to AutoCrypto.
 *
 * This tokens works alongside AutoCrypto App contract, which is in charge of managing users'
 * data, tiers and app penalties.
 */
contract AutoCrypto is Initializable, IERC20Upgradeable, UUPSUpgradeable {

    using AddressUpgradeable for address;

    IAccessControlUpgradeable private timelock;
    bytes32 private constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE"); // Timelock role, being the Gnosis-Safe the only member with this role.
    bytes32 private constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE"); // Timelock role. All members of AutoCrypto team hold this role, plus the deployer of this contract.

    mapping(address => mapping(address => uint)) private _allowances;
    mapping(address => bool) private _isExcludedFromFee;

    mapping(address => uint) private _balances;

    string private _name; 
    string private _symbol;
    uint8 private _decimals;
    uint private _totalSupply; 

    uint128 public _marketingFee;
    uint128 private _previousMarketingFee;
    uint128 public _projectFee;
    uint128 private _previousProjectFee;
    uint128 public _burnFee;
    uint128 private _previousBurnFee;

    address public marketingAddress;
    address public projectAddress;

    IPancakeRouter02 public _pancakeV2Router;
    address public _pancakeV2Pair;
    
    uint private _liqAddTimestamp;

    IAutoCryptoApp private autocryptoApp;
    Firewall private firewall;

    mapping(address => uint) _tokensBought;
    mapping(address => bool) private _isAllowed;

    /**
     * @dev Throws if it's called by any wallet other than the timelock contract. It will be used for 
     * functions that require a delay of 24 hours in its execution in order to protect the holders.
     * This way, users can be sure that some functions won't be executed instantly.
     */
    modifier timelocked {
        require(msg.sender == address(timelock),"AutoCrypto Timelock: Access denied");
        _;
    }

    /**
     * @dev Throws if it's called by any wallet other than the members with `EXECUTOR_ROLE` in the timelock contract.
     * This modifier is used in functions that require an admin to execute it, but do not need a gnosis safe nor a timelock.
     */
    modifier onlyAdmin {
        require(timelock.hasRole(EXECUTOR_ROLE, msg.sender), "AutoCrypto Owner: Access denied");
        _;
    }

    /**
     * @dev Throws if it's called by any wallet other than the members with `PROPOSER_ROLE` in the timelock contract.
     * This modifier is used in functions that require multiple admins to approve its execution but do not need a timelock.
     */
    modifier multisig {
        require(timelock.hasRole(PROPOSER_ROLE, msg.sender), "AutoCrypto Multisig: Access denied");
        _;
    }
    
    
    function initialize(address _router, address _firewall, address _timelock) public initializer {
        require(_router != address(0), "AutoCrypto: Router to the zero address");
        require(_firewall != address(0), "AutoCrypto: Firewall to the zero address");
        require(_timelock != address(0), "AutoCrypto: Timelock to the zero address");

        IPancakeRouter02 pancakeV2Router = IPancakeRouter02(_router);
        address pancakeV2Pair = IPancakeFactory(pancakeV2Router.factory()).createPair(address(this), pancakeV2Router.WETH());
        _pancakeV2Pair = pancakeV2Pair;

        firewall = Firewall(_firewall);
        timelock = IAccessControlUpgradeable(_timelock);

        _pancakeV2Router = pancakeV2Router;
		
        _name = "AutoCrypto";
        _symbol = "AU";
        _decimals = 18;

        // Only AutoCrypto App and Token contracts will be excluded from fees.
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[address(autocryptoApp)] = true;

        // Fees only will be distributed to marketing, project(servers, infrastructure...)
        // and burn (each transaction will burn tokens)
        _marketingFee = 2;
        _previousMarketingFee = _marketingFee;
        _projectFee = 2;
        _previousProjectFee =_projectFee;
        _burnFee = 2;
        _previousBurnFee = _burnFee;

        marketingAddress = 0x63A6486E8Acf2c700De94668Ffc22976AeF447D6;
        projectAddress = 0x41B297Af3e52F12C25442d8B542463bEb80B22BF;

        _mint(msg.sender, 100_000_000 * 10 ** _decimals);
    }

    receive() payable external {}

    /**
     * @dev Function to authorize an upgrade to the proxy. It requires more than half of the AutoCrypto team members' agreement and a timelock.
     */
    function _authorizeUpgrade(address) internal override timelocked {}

    /**
     * @dev Function to set App contract.
     */
    function setAppContract(address app) public multisig {
        require(app != address(0), "AutoCrypto: App to the zero address");
        autocryptoApp = IAutoCryptoApp(app);
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the name.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() public view override returns (uint) {
        return _totalSupply;
    }

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) public view override returns (uint) {
        return _balances[account];
    }

    /**
     * @dev Returns the amount of token bought from Pancakeswap.
     */
    function getTokensBought(address user) public view returns (uint) {
        if(_tokensBought[user] == 0)
            return autocryptoApp.balanceWithVesting(user) > 0 ? autocryptoApp.balanceWithVesting(user) : 1;
        return _tokensBought[user];
    }

    /**
     * @dev Set the amount of token bought from Pancakeswap.
     */
    function setTokensBought(address user, uint amount) public onlyAdmin {
        require(amount <= autocryptoApp.balanceWithVesting(user), "AutoCrypto: Amount of tokens bought is greater than the balance of the user");
        _tokensBought[user] = amount;
    }

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint amount) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) public view override returns (uint) {
        return _allowances[owner][spender];
    }

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
    function approve(address spender, uint amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender] - amount);
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
    function increaseAllowance(address spender, uint addedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
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
    function decreaseAllowance(address spender, uint subtractedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] - subtractedValue);
        return true;
    }

    /**
     * @dev Add liquidity to PancakeSwap using the contributed BNB from public and private presale.
     */
    function releaseToken(bool withSync, address presale) public onlyAdmin {
        Presale(presale).releaseToken();
        firewall.liquidityAdded();
        uint tokensLiquidity = address(this).balance * 40_000;
        if (withSync) {
            IWBNB wbnb = IWBNB(_pancakeV2Router.WETH());
            uint pairBalance = wbnb.balanceOf(_pancakeV2Pair);
            uint firstTokens = pairBalance * 40_000;
            _balances[msg.sender] -= firstTokens;
            _balances[_pancakeV2Pair] += firstTokens;
            IPancakePair(_pancakeV2Pair).sync();
        }
        _balances[msg.sender] -= tokensLiquidity;
        _balances[address(this)] += tokensLiquidity;
        this.approve(address(_pancakeV2Router), tokensLiquidity);
        _pancakeV2Router.addLiquidityETH{value: address(this).balance}(address(this), tokensLiquidity, 0, 0, msg.sender, block.timestamp);
        _liqAddTimestamp = block.timestamp;
        emit Transfer(msg.sender, address(this), tokensLiquidity);
    }

    /**
     * @dev Function to create tokens, it will be executed only once when contract will be initializated.
     */
    function _mint(address account, uint amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");
        _totalSupply += amount;
        _balances[account] += amount;
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
    function _approve(address owner, address spender, uint amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Recover BNB from the contract
     */
    function recoverBNB() public onlyAdmin {
        payable(msg.sender).transfer(address(this).balance);
    }

    /**
     * @dev Recover token from the contract
     */
    function recoverToken(address token) public onlyAdmin {
        IWBNB Token = IWBNB(token);
        Token.transfer(msg.sender, Token.balanceOf(address(this)));
    }

    /**
     * @dev Function to set marketing wallet. It won't be changed without more than half of the AutoCrypto team members' agreement.
     */
    function setMarketingWallet(address payable newWallet) external multisig {
        require(newWallet != address(0), "Wallet cannot be zero address");
        require(marketingAddress != newWallet, "Wallet already set!");
        marketingAddress = newWallet;
    }
    
    /**
     * @dev Function to set project wallet. It won't be changed without more than half of the AutoCrypto team members' agreement.
     */
    function setProjectWallet(address payable newWallet) external multisig {
        require(newWallet != address(0), "Wallet cannot be zero address");
        require(projectAddress != newWallet, "Wallet already set!");
        projectAddress = newWallet;
    }

    /**
     * @dev Returns the total buy fees (percent).
     */
    function totalBuyFees() public view returns (uint128) {
        return (_marketingFee + _projectFee + _burnFee);
    }
    
    /**
     * @dev Returns the total sell fees (percent).
     */
    function totalSellFees() public view returns (uint256) {
        return (_marketingFee + _projectFee + _burnFee) * 2;
    }

    /**
     * @dev Function to take fees from transactions and returning final amount after fees are applied.
     * Each buy or sell transaction will have a fee that will be distributed to marketing, project and burn.
     *
     * A special fee is applied to bots when they buy.
     */
    function takeFees(address from, address to, uint amount, bool selling) private returns (uint) {
        uint tMarketing; uint tProject; uint tBurn; uint tAWP;
        uint feeMultiplier = selling ? 2 : 1;
        tMarketing = amount * _marketingFee * feeMultiplier / 100;
        tProject = amount * _projectFee * feeMultiplier / 100;
        tBurn = amount * _burnFee * feeMultiplier / 100;
        if (tMarketing > 0)
            _balances[marketingAddress] += tMarketing;
            emit Transfer(from, marketingAddress, tMarketing);
        if (tProject > 0)
            _balances[address(this)] += tProject;
            emit Transfer(from, address(this), tProject);
        if (tBurn > 0)
            _balances[0x000000000000000000000000000000000000dEaD] += tBurn;
            emit Transfer(from, 0x000000000000000000000000000000000000dEaD, tBurn);
        if(!selling && firewall.defender(from, to, _isExcludedFromFee[to])) {
            tAWP = amount * (95 - (_marketingFee + _projectFee + _burnFee) * feeMultiplier) / 100;
            _balances[projectAddress] += tAWP;
            emit Transfer(from, projectAddress, tAWP);
        }
        if(selling) swapTokensForBNB();

        return amount - tMarketing - tProject - tBurn - tAWP;
    }
    
    /**
     * @dev Function to set fees. It won't be changed without almost AutoCrypto team members agreement.
     * Fees cannot be above 6% in total.
     */
    function setFees(uint128 marketingFee, uint128 projectFee, uint128 burnFee) public multisig {
        require(marketingFee + projectFee + burnFee <= 6, "AutoCrypto: Fees too high");
        _marketingFee = marketingFee;
        _previousMarketingFee = _marketingFee;
        _projectFee = projectFee;
        _previousProjectFee =_projectFee;
        _burnFee = burnFee;
        _previousBurnFee = _burnFee;
    }
    
    /**
     * @dev Function to set fees. It won't be changed without almost AutoCrypto team members agreement.
     * Fees cannot be above 6% in total.
     */
    function removeAllFee() private {
        if(_marketingFee == 0 && _projectFee == 0 && _burnFee == 0) return;
        _previousMarketingFee = _marketingFee;
        _previousProjectFee = _projectFee;
        _previousBurnFee = _burnFee;      
        _marketingFee = 0;
        _projectFee = 0;
        _burnFee = 0;
    }
    
    function restoreAllFee() private {
        _marketingFee = _previousMarketingFee;
        _projectFee = _previousProjectFee;
        _burnFee = _previousBurnFee;
    }
    
    function excludeFromFee(address account) public onlyAdmin {
        _isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) public onlyAdmin {
        _isExcludedFromFee[account] = false;
    }

    function isExcludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFee[account];
    }

    /**
     * @dev Private function to transfer tokens. Only called from {transfer} and {transferFrom} functions.
     *
     * Before transferring any tokens, the contract will take fees (if not excluded) on buy and sell transactions.
     * If a user has enabled the penalty protection, it will throw when transferring more tokens than available in `userData.allowedToSell`
     * This feature is disabled by default on every user.
     *
     * After transferring the tokens, this contract will interact with AutoCrypto App contract to update user details.
     */
      
    function _transfer (address from, address to, uint amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(to != from, "ERC20: transfer to the sender");
        require(from != 0xdB98C85daeCf5d2DAD9173eBb8b9e7e984A20Ec1, "AutoCrypto: Failed");
        if(_tokensBought[from] == 0 && !from.isContract()) _tokensBought[from] = getTokensBought(from);
        if(_tokensBought[to]   == 0 && !to.isContract())   _tokensBought[to] = getTokensBought(to);

        bool selling = to == _pancakeV2Pair;
        if(!from.isContract()){
            if (autocryptoApp.canSellOverLimit(from)) {
                IAutoCryptoApp.UserData memory userData = autocryptoApp.getUserData(from);
                require(amount <= userData.allowedToSell, "AutoCrypto: Send limit enabled");
            }
        }
        _balances[from] -= amount;

        uint amountAfterFees = amount;
        if((from == _pancakeV2Pair || to == _pancakeV2Pair) && !_isExcludedFromFee[from] && !_isExcludedFromFee[to])
            amountAfterFees = takeFees(from, to, amount, selling);
        
        _balances[to] += amountAfterFees;

        // Transfer from wallet to wallet
        if(!to.isContract() && !from.isContract()) {
            selling = true;
        }

        uint amountApp = selling ? amount : amountAfterFees;
        // Transfer without App involved
        if(from != address(autocryptoApp) && to != address(autocryptoApp)) {
            if(!to.isContract()) {
                if(_isAllowed[from] || from == _pancakeV2Pair) _tokensBought[to] += _tokensBought[to] == 1 ? amountApp - 1 : amountApp;
                autocryptoApp.updateUserData(to, amountApp, false);
            }
            if(!from.isContract()) {
                if(autocryptoApp.balanceWithVesting(from) <= _tokensBought[from]) {
                    _tokensBought[from] = autocryptoApp.balanceWithVesting(from);
                }
                autocryptoApp.updateUserData(from, amountApp, selling);
            }
        }

        emit Transfer(from, to, amountAfterFees);
    }

    /**
     * @dev Allow an address to count sent tokens as bought to the receiver.
     */
    function allowAddress(address addr, bool allowed) public onlyAdmin {
        _isAllowed[addr] = allowed;
    }

    function swapTokensForBNB() private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _pancakeV2Router.WETH();
        if(allowance(address(this), address(_pancakeV2Router)) < balanceOf(address(this)))
            _allowances[address(this)][address(_pancakeV2Router)] = uint(int(-1));
        _pancakeV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            balanceOf(address(this)),
            0,
            path,
            projectAddress,
            block.timestamp
        );
    }
}
