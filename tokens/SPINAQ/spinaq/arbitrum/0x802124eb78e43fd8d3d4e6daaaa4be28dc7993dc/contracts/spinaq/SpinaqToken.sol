// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";

interface IUniswapV2Router02 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
}

contract SpinaqToken is ERC20, ERC20Permit, AccessControl {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant RESCUER_ROLE = keccak256("RESCUER_ROLE");
    bytes32 public constant TAKE_FEE_ROLE = keccak256("TAKE_FEE_ROLE");
    bytes32 public constant ROUTER_ROLE = keccak256("ROUTER_ROLE");

     // 21% initial supply 
     // 1%(1_929_000) LP
     // 20%(38_580_000) 6 month lock
    uint256 private _initialSupply = 40_509_000 * 10**decimals();
    uint256 private _maxSupply = 192_900_000 * 10**decimals();

    uint256 private changeMinter;
    uint256 public constant MINT_DELAY = 7 days;

    address private _trustedForwarder;
    bool private initialized;

    // Control support for EIP-2771 Meta Transactions
    bool public metaTxnsEnabled = false;

    // START FEES LOGIC
    IUniswapV2Router02 public immutable _router;
    address public immutable pair;

    bool private swapping;

    address public _treasuryWallet;

    uint256 public buyTreasuryFee;
    uint256 public sellTreasuryFee;
    uint256 public tokensForTreasury;

    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) public automatedMarketMakerPairs;
    // END FEES LOGIC

    event TokensRescued(address indexed sender, address indexed token, uint256 value);
    event MetaTxnsEnabled(address indexed caller);
    event MetaTxnsDisabled(address indexed caller);
    event MinterChange(uint timestamp, uint executionStart);

    constructor(address trustedForwarder, address router, address treasuryWallet) ERC20("Spinaq", "SPINAQ") ERC20Permit("Spinaq") {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(RESCUER_ROLE, _msgSender());

        _trustedForwarder = trustedForwarder;

        // START FEES LOGIC
        buyTreasuryFee = 4; // 4%
        sellTreasuryFee = 4; // 4%
        _treasuryWallet = treasuryWallet;

        _router = IUniswapV2Router02(router);
        pair = IUniswapV2Factory(_router.factory()).createPair(address(this), _router.WETH());

        automatedMarketMakerPairs[address(pair)] = true;

        _isExcludedFromFees[_msgSender()] = true;
        _isExcludedFromFees[address(this)] = true;
        _isExcludedFromFees[address(0xdead)] = true;
        // END FEES LOGIC

        //mint initial supply in constructor, rest in contract
        _mint(_msgSender(), _initialSupply);
    }

    //single use function to set up Distributor as minter
    function initialize(address minter) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!initialized, "AI");
        _setupRole(MINTER_ROLE, minter);
        excludeFromFees(minter, true);
        initialized = true;
    }

    function excludeFromFees(address account, bool excluded) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _isExcludedFromFees[account] = excluded;
    }


    function isTrustedForwarder(address forwarder) public view virtual returns (bool) {
        return forwarder == _trustedForwarder;
    }

    function setAutomatedMarketPairs(
        address addr,
        bool value
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        automatedMarketMakerPairs[addr] = value;
    }

    function setBuyFee(
        uint256 value
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(value < 5, "Buy fee cant be greater than 5%");

        buyTreasuryFee = value;
    }


    function setSellFee(
        uint256 value
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(value < 5, "Sell fee cant be greater than 5%");

        sellTreasuryFee = value;
    }

    function _msgSender() internal view override returns (address sender) {
        if (isTrustedForwarder(msg.sender)) {
            // The assembly code is more direct than the Solidity version using `abi.decode`.
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            return super._msgSender();
        }
    }

    function _msgData() internal view override returns (bytes calldata) {
        if (isTrustedForwarder(msg.sender)) {
            return msg.data[:msg.data.length - 20];
        } else {
            return super._msgData();
        }
    }

    /**
     * @dev Returns the maximum amount of tokens that can be minted.
     */
    function maxSupply() public view returns (uint256) {
        return _maxSupply;
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        require(totalSupply() + amount <= _maxSupply, "ERC20: cannot mint more tokens, cap exceeded");
        _mint(to, amount);
    }

    //Function to start minter change timelock
    //Minting is done by contract, but we might want to change minting rules later
    //Since this is a touchy subject, best to add timelock
    function setUpMinter() external onlyRole(DEFAULT_ADMIN_ROLE) {
        //no checks, allows refreshing timer
        changeMinter = block.timestamp;
        emit MinterChange(changeMinter, changeMinter + MINT_DELAY);
    }

    function grantRole(bytes32 role, address account) public override onlyRole(getRoleAdmin(role)) {
        if(role == MINTER_ROLE) {
            require(changeMinter != 0 && block.timestamp >= changeMinter + MINT_DELAY, "MTE");
            require(block.timestamp <= changeMinter + (MINT_DELAY * 2), "EXP");
            changeMinter = 0; //reset
        }
        super.grantRole(role, account);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        bool takeFee = !swapping;

        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }
        
        uint256 fees = 0;
        // only take fees on buys/sells, do not take on wallet transfers
        if (takeFee) {
            // on sell
            if (automatedMarketMakerPairs[to] && sellTreasuryFee > 0) {
                fees = amount.mul(sellTreasuryFee).div(100);
                tokensForTreasury += fees;
            }
            // on buy
            else if (automatedMarketMakerPairs[from] && buyTreasuryFee > 0) {
                fees = amount.mul(buyTreasuryFee).div(100);
                tokensForTreasury += fees;
            }

            if (fees > 0) {
                super._transfer(from, _treasuryWallet, fees);
            }

            amount -= fees;
        }

        super._transfer(from, to, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._beforeTokenTransfer(from, to, amount);
    }

    function rescueTokens(IERC20 token, uint256 value) external onlyRole(RESCUER_ROLE) {
        token.transfer(_msgSender(), value);

        emit TokensRescued(_msgSender(), address(token), value);
    }

    // Enable support for meta transactions
    function enableMetaTxns() public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!metaTxnsEnabled, "Meta transactions are already enabled");

        metaTxnsEnabled = true;
        emit MetaTxnsEnabled(_msgSender());
    }

    // Disable support for meta transactions
    function disableMetaTxns() public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(metaTxnsEnabled, "Meta transactions are already disabled");

        metaTxnsEnabled = false;
        emit MetaTxnsDisabled(_msgSender());
    }
}
