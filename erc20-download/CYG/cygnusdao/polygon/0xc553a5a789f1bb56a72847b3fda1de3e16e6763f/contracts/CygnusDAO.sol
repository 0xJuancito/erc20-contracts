// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

// Dependencies
import {IERC20, OFT} from "@layerzerolabs/solidity-examples/contracts/token/oft/OFT.sol";

/**
 *  @title CygnusDAO CYG token built as layer-zero`s OFT.
 *  @notice On each chain the CYG token is deployed there is a cap of 2.5M to be minted over 42 epochs (4 years).
 *          See https://github.com/CygnusDAO/cygnus-token/blob/main/contracts/cygnus-token/PillarsOfCreation.sol
 *          Instead of using `totalSupply` to cap the mints, we must keep track internally of the total minted
 *          amount, to not break compatability with the OFT's `_debitFrom` and `_creditTo` functions (since these
 *          burn and mint supply into existence respectively).
 */
contract CygnusDAO is OFT {
    /*  ═══════════════════════════════════════════════════════════════════════════════════════════════════════ 
            1. EVENTS AND ERRORS
        ═══════════════════════════════════════════════════════════════════════════════════════════════════════  */

    /// @custom:event NewCYGMinter Emitted when the CYG minter contract is set, only emitted once
    event NewCYGMinter(address oldMinter, address newMinter);

    /// @custom:event Migrate Emitted when a user migrates from the old CYG
    event Migrate(address user, uint256 amount);

    /// @custom:error ExceedsSupplyCap Reverts when minting above cap
    error ExceedsSupplyCap();

    /// @custom:error PillarsAlreadySet Reverts when assigning the minter contract again
    error PillarsAlreadySet();

    /// @custom:error OnlyPillars Reverts when msg.sender is not the CYG minter contract
    error OnlyPillars();

    /// @custom:error InsufficientBalance Reverts if already migrated or has no balance
    error InsufficientBalance();

    /*  ═══════════════════════════════════════════════════════════════════════════════════════════════════════ 
            2. STORAGE
        ═══════════════════════════════════════════════════════════════════════════════════════════════════════  */

    /// @notice Maximum cap of CYG on this chain
    uint256 public constant CAP = 2_500_000e18;

    /// @notice The CYG minter contract
    address public pillarsOfCreation;

    /// @notice Stored minted amount
    uint256 public totalMinted;

    /*  ═══════════════════════════════════════════════════════════════════════════════════════════════════════ 
            3. CONSTRUCTOR
        ═══════════════════════════════════════════════════════════════════════════════════════════════════════  */

    /// @notice Constructs the CYG OFT token and gives sender initial ownership to set paths.
    constructor(string memory _name, string memory _symbol, address _lzEndpoint) OFT(_name, _symbol, _lzEndpoint) {
        // Every chain deployment is the same, 250,000 inital mint rest to pillars
        uint256 initial = 250_000e18;

        // Increase initial minted
        totalMinted += initial;

        // Mint initial supply to admin
        _mint(_msgSender(), initial);
    }

    /*  ═══════════════════════════════════════════════════════════════════════════════════════════════════════ 
            4. MODIFIERS
        ═══════════════════════════════════════════════════════════════════════════════════════════════════════  */

    /// @notice Modifier for minting only if msg.sender is CYG minter contract
    modifier onlyPillars() {
        _checkPillars();
        _;
    }

    /*  ═══════════════════════════════════════════════════════════════════════════════════════════════════════ 
            5. CONSTANT FUNCTIONS
        ═══════════════════════════════════════════════════════════════════════════════════════════════════════  */

    /*  ─────────────────────────────────────────────── Private ───────────────────────────────────────────────  */

    /// @notice Reverts if msg.sender is not CYG minter
    function _checkPillars() private view {
        /// @custom:error OnlyPillars
        if (_msgSender() != pillarsOfCreation) revert OnlyPillars();
    }

    /*  ═══════════════════════════════════════════════════════════════════════════════════════════════════════ 
            6. NON-CONSTANT FUNCTIONS
        ═══════════════════════════════════════════════════════════════════════════════════════════════════════  */

    /*  ────────────────────────────────────────────── External ───────────────────────────────────────────────  */

    /// @notice Mints CYG token into existence. Uses stored `totalMinted` instead of `totalSupply` as to not break
    //          compatability with lzapp's `_debitFrom` and `_creditTo` functions
    /// @notice Only the `pillarsOfCreation` contract may mint
    /// @param to The receiver of the CYG token
    /// @param amount The amount of CYG token to mint
    /// @custom:security only-pillars-contract
    function mint(address to, uint256 amount) external onlyPillars {
        // Gas savings
        uint256 _totalMinted = totalMinted + amount;

        /// @custom:error ExceedsSupplyCap Avoid minting above cap
        if (_totalMinted > CAP) revert ExceedsSupplyCap();

        // Increase minted amount
        totalMinted = _totalMinted;

        // Mint internally
        _mint(to, amount);
    }

    /// @notice Assigns the only contract on the chain that can mint the CYG token. Can only be set once.
    /// @param _pillars The address of the minter contract
    /// @custom:security only-admin
    function setPillarsOfCreation(address _pillars) external onlyOwner {
        // Current CYG minter
        address currentPillars = pillarsOfCreation;

        /// @custom:error PillarsAlreadySet Avoid setting the CYG minter again if already initialized
        if (currentPillars != address(0)) revert PillarsAlreadySet();

        /// @custom:event NewCYGMinter
        emit NewCYGMinter(currentPillars, pillarsOfCreation = _pillars);
    }

    /* ──────── Only for Polygon Mainnet ──────── */

    /// @notice Old CYG token
    address public constant OLD_CYGNUS_TOKEN = 0xc115521DC2D0F950AD5D3589D0a4b22239C56A1B;

    /// @notice Migrate old CYG to OFT
    function migrate() external {
        // Get migrator
        address migrator = _msgSender();

        // Get current balance
        uint256 balance = IERC20(OLD_CYGNUS_TOKEN).balanceOf(migrator);

        // Check balance
        if (balance > 0) {
            // Burn old CYG to zero address
            IERC20(OLD_CYGNUS_TOKEN).transferFrom(migrator, address(0), balance);

            // Increase
            totalMinted += balance;

            // Mint to migrator
            _mint(migrator, balance);
        }
        // Revert if user has no balance
        else revert("Insufficient Balance");

        /// @custom:event Migrate
        emit Migrate(migrator, balance);
    }
}
