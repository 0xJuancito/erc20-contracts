
pragma solidity ^0.6.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract LumiiiStorage {
    using SafeMath for uint256;
    using Address for address;

    /// @notice Reflected amount owned for each address
    mapping(address => uint256) internal _rOwned;
    /// @notice True amount owned for each address
    mapping(address => uint256) internal _tOwned;
    /// @notice Allowance for each address
    mapping(address => mapping(address => uint256)) internal _allowances;

    /// @notice Fee exclusion for each address
    mapping(address => bool) internal _isExcludedFromFee;

    /// @notice Rewards exclusion for each address
    mapping(address => bool) internal _isExcluded;

    /// @notice Each accounts delegates
    mapping(address => address) internal _delegates;
    /// @notice A record of votes checkpoints for each account, by index
    mapping(address => mapping(uint32 => Checkpoint)) public checkpoints;

    /// @notice The number of checkpoints for each account
    mapping(address => uint32) public numCheckpoints;

    /// @notice Excluded addressess
    address[] internal _excluded;

    address _charityWallet;
    address _opsWallet;

    /// @notice Max uint256 values
    uint256 internal constant MAX = ~uint256(0);
    /// @notice True total
    uint256 internal _tTotal = 10000  * 10**6 * 10**18;
    /// @notice Reflected total
    uint256 internal _rTotal = (MAX - (MAX % _tTotal));
    /// @notice True fee total
    uint256 internal _tFeeTotal;

    string internal _name = "LumiiiToken";
    string internal _symbol = "LUMIII";
    uint8 internal _decimals = 18;

    /// @notice Reflection tax fee
    uint256 public _taxFee = 3;
    uint256 internal _previousTaxFee = _taxFee;

    /// @notice Liquidity tax fee
    uint256 public _liquidityFee = 3;
    uint256 internal _previousLiquidityFee = _liquidityFee;

    /// @notice Charity tax fee
    uint256 public _charityFee = 1;
    uint256 internal _previousCharityFee = _charityFee;

    /// @notice operations fee
    uint256 public _opsFee = 3;
    uint256 internal _previousOpsFee = _opsFee;

    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;

    /// @notice Max tax amount
    uint256 public _maxTxAmount = 50 * 10**6 * 10**18;
    /// @notice Token threshold for adding to uniswap liquidity pool
    uint256 internal numTokensSellToAddToLiquidity = 5 * 10**6 * 10**18;

    /// @notice Struct for getValues functions
    struct valueStruct {
        uint256 transferAmount;
        uint256 fee;
        uint256 liquidity;
        uint256 charity;
        uint256 ops;
    }

    /// @notice Struct for checkpoints
    struct Checkpoint {
        uint32 fromBlock;
        uint256 votes;
    }
}
