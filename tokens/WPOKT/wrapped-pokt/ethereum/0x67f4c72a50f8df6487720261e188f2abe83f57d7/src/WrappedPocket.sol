// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "openzeppelin-contracts/contracts/security/Pausable.sol";
import "openzeppelin-contracts/contracts/access/AccessControl.sol";
import "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract WrappedPocket is ERC20, ERC20Burnable, Pausable, AccessControl, ERC20Permit {
    /*//////////////////////////////////////////////////////////////
    // Immutable storage
    //////////////////////////////////////////////////////////////*/
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_FEE_BASIS = 300;

    /*//////////////////////////////////////////////////////////////
    // State
    //////////////////////////////////////////////////////////////*/
    bool public feeFlag;
    uint256 public feeBasis;
    address public feeCollector;

    mapping(address => uint256) private _userNonces;

    /*//////////////////////////////////////////////////////////////
    // Events and Errors
    //////////////////////////////////////////////////////////////*/
    event FeeSet(bool indexed flag, uint256 indexed newFeeBasis, address indexed feeCollector);
    event FeeCollected(address indexed feeCollector, uint256 indexed amount);
    event BurnAndBridge(uint256 indexed amount, address indexed poktAddress, address indexed from);
    event Minted(address indexed recipient, uint256 indexed amount, uint256 indexed nonce);

    error UserNonce(address user, uint256 nonce);
    error FeeCollectorZero();
    error FeeBasisDust();
    error BatchMintLength();
    error MaxBasis();
    error BlockBurn();

    constructor() ERC20("Wrapped Pocket", "wPOKT") ERC20Permit("Wrapped Pocket") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
    // Public and External Mutative Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Burn tokens from the caller's account and emits an event for bridging the amount to the Pocket blockchain.
     * @param amount The amount of tokens to burn.
     * @param poktAddress The recipient address on the Pocket blockchain.
     */
    function burnAndBridge(uint256 amount, address poktAddress) public whenNotPaused {
        _burn(msg.sender, amount);
        emit BurnAndBridge(amount, poktAddress, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
    // Access Control
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Pause the contract functions. Can only be called by an account with the `PAUSER_ROLE`.
     */
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the contract functions. Can only be called by an account with the `PAUSER_ROLE`.
     */
    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @notice Mints tokens to a specific address.
     * Can only be called by an account with the `MINTER_ROLE`.
     * @param to The address to mint tokens to.
     * @param amount The amount of tokens to mint.
     * @param nonce The nonce associated with the address.
     */
    function mint(address to, uint256 amount, uint256 nonce) public onlyRole(MINTER_ROLE) whenNotPaused {
        uint256 currentNonce = _userNonces[to];

        if (nonce != currentNonce + 1) {
            revert UserNonce(to, nonce);
        }

        if (feeFlag == true) {
            amount = _collectFee(amount);
        }

        _userNonces[to] = nonce;
        _mint(to, amount);
        emit Minted(to, amount, nonce);
    }

    /**
     * @notice Mints tokens in batches to multiple addresses.
     * Can only be called by an account with the `MINTER_ROLE`.
     * @param to An array of addresses to mint tokens to.
     * @param amount An array of amounts to mint for each address.
     * @param nonce An array of nonces associated with each address.
     */
    function batchMint(address[] calldata to, uint256[] calldata amount, uint256[] calldata nonce)
        public
        onlyRole(MINTER_ROLE)
        whenNotPaused
    {
        uint256 toLength = to.length;

        if (toLength != amount.length || toLength != nonce.length) {
            revert BatchMintLength();
        }

        if (feeFlag == true) {
            uint256[] memory adjustedAmounts = _batchCollectFee(amount);

            for (uint256 i; i < toLength;) {
                _mintBatch(to[i], adjustedAmounts[i], nonce[i]);
                unchecked {
                    ++i;
                }
            }
        } else {
            for (uint256 i; i < toLength;) {
                _mintBatch(to[i], amount[i], nonce[i]);
                unchecked {
                    ++i;
                }
            }
        }
    }

    /**
     * @notice Set the fee parameters. Can only be called by an account with the `DEFAULT_ADMIN_ROLE`.
     * @param flag Boolean indicating if fee is enabled or not.
     * @param newFee The new fee basis points.
     * @param newCollector The address where collected fee will be sent.
     */
    function setFee(bool flag, uint256 newFee, address newCollector) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newCollector == address(0) && flag == true) {
            revert FeeCollectorZero();
        }

        if (newFee > MAX_FEE_BASIS) {
            revert MaxBasis();
        }

        feeBasis = newFee;
        feeFlag = flag;
        feeCollector = newCollector;
        emit FeeSet(flag, newFee, newCollector);
    }

    /*//////////////////////////////////////////////////////////////
    // Internal and Private Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to mint tokens from a batch.
     * @param to The address to mint tokens to.
     * @param amount The amount of tokens to mint.
     * @param nonce The nonce associated with the address.
     */
    function _mintBatch(address to, uint256 amount, uint256 nonce) private {
        uint256 currentNonce = _userNonces[to];

        if (nonce != currentNonce + 1) {
            revert UserNonce(to, nonce);
        }

        _userNonces[to] = nonce;
        _mint(to, amount);
        emit Minted(to, amount, nonce);
    }

    /**
     * @notice Collects a fee from the minting operation.
     * @param amount The amount of tokens minted.
     * @return The net amount after fee deduction.
     */
    function _collectFee(uint256 amount) internal returns (uint256) {
        if (amount % BASIS_POINTS != 0) {
            revert FeeBasisDust();
        }

        uint256 fee = (amount * feeBasis) / BASIS_POINTS;
        _mint(feeCollector, fee);
        emit FeeCollected(feeCollector, fee);
        return amount - fee;
    }

    /**
     * @notice Collects a fee from the batch minting operation and calculates the adjusted amounts.
     * @param amounts Array of mint amounts.
     * @return The array of adjusted amounts.
     */
    function _batchCollectFee(uint256[] calldata amounts) internal returns (uint256[] memory) {
        uint256 fee;
        uint256 totalFee;
        uint256[] memory adjustedAmounts = new uint256[](amounts.length);

        uint256 amountLength = amounts.length;
        for (uint256 i; i < amountLength;) {
            if (amounts[i] % BASIS_POINTS != 0) {
                revert FeeBasisDust();
            }
            fee = (amounts[i] * feeBasis) / BASIS_POINTS;
            adjustedAmounts[i] = amounts[i] - fee;
            totalFee += fee;
            unchecked {
                ++i;
            }
        }

        _mint(feeCollector, totalFee);
        emit FeeCollected(feeCollector, totalFee);
        return adjustedAmounts;
    }

    /*//////////////////////////////////////////////////////////////
    // View Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get the current nonce for a user.
     * @param user The user's address.
     * @return The current nonce of the user.
     */
    function getUserNonce(address user) public view returns (uint256) {
        return _userNonces[user];
    }

    /*//////////////////////////////////////////////////////////////
    // Overrides
    //////////////////////////////////////////////////////////////*/

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    /**
     * @notice Hook that is called before any token transfer including mints and burns.
     * @param from The sender address.
     * @param to The recipient address.
     * @param amount The amount of tokens to transfer.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }

    /**
     * @notice Burns tokens. This function is blocked and cannot be called.
     */
    function burn(uint256) public pure override {
        revert BlockBurn();
    }
}
