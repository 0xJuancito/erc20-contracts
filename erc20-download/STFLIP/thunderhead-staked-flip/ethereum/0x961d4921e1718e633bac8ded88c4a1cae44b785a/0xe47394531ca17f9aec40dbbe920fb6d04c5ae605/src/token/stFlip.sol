// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.7;

import "./tStorage.sol";
import "../utils/Ownership.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/governance/utils/VotesUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@solmate/src/utils/FixedPointMathLib.sol";

/**
 * @title stFlip token contract
 * @notice This is the token contract for StakedFLIP. It is backed 1:1 by native FLIP. 
 * It is rebasing and also a voting token. After each transfer, a new checkpoint is added via `votesUpgradeable` which we have modified to automatically
 * self-delegate every address and disable delegation to every address, thus the latest checkpoint is the
 * shares for a given address. This fork is here: https://github.com/thunderhead-labs/openzeppelin-contracts-upgradeable.
 * The changes are trivial. `shares` is the representation used for balance in storage,
 * although the real balance multiplies shares by totalSupply/totalShares. totalSupply linearly increases after 
 * the Rebaser calls syncSupply which starts a new reward distribution interval. Shares have 24 decimals while actual balance has 18 decimals
 * this is to avoid rounding issues when dealing with 1 wei of balance. Relevant sources: https://forum.openzeppelin.com/t/self-delegation-in-erc20votes/17501/17 and 
 * https://github.com/aragon/osx/blob/a52bbae69f78e74d6a17647370ccfa2f2ea9bbf0/packages/contracts/src/token/ERC20/governance/GovernanceERC20.sol#L113
 */
contract stFlip is Initializable, Ownership, TokenStorage, VotesUpgradeable {
    using FixedPointMathLib for uint256;
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Event emitted when tokens are rebased
     */
    event Rebase(uint256 epoch, uint256 currentSupply, uint256 newSupply, uint256 rebaseInterval);

    /* - ERC20 Events - */

    /**
     * @notice EIP20 Transfer event
     */
    event Transfer(address indexed from, address indexed to, uint amount);

    /**
     * @notice EIP20 Approval event
     */
    event Approval(address indexed owner, address indexed spender, uint amount);

    /* - Extra Events - */
    /**
     * @notice Tokens minted event
     */
    event Mint(address to, uint256 amount);

    error TransferIsPaused();

    error MintIsPaused();

    error BurnIsPaused();

    error RebaseIsPaused();


    /**
     * Modifier to ensure token is not paused from transferring
     */
    modifier notTransferPaused() {
        if (transferPaused == true) {
            revert TransferIsPaused();
        }
        _;
    }

    /**
     * Modifier to ensure token is not paused from minting
     */
    modifier notMintPaused() {
        if (mintPaused == true) {
            revert MintIsPaused();
        }
        _;
    }

    /**
     * Modifier to ensure token is not paused from burning
     */
    modifier notBurnPaused() {
        if (burnPaused == true) {
            revert BurnIsPaused();
        }
        _;
    }

    /**
     * Modifier to ensure rebase are not paused
     */
    modifier notRebasePaused() {
        if (rebasePaused == true) {
            revert RebaseIsPaused();
        }
        _;
    }

    
    /**
     * Sets initial initialization parameters
     * @param name_ Token name (Staked Chainflip)
     * @param symbol_ Token symbol (stFLIP)
     * @param decimals_ Decimals (18)
     * @param gov_ Governance address
     * @param initialSupply_ Initial supply (0)
     */
    function initialize(string memory name_, string memory symbol_, uint8 decimals_, address gov_, uint256 initialSupply_, address burner, address minter, address rebaser) initializer public {
        name = name_;
        symbol = symbol_;
        decimals = decimals_;

        preSyncSupply = SafeCast.toUint96(initialSupply_);
        rewardsToSync = 0;
        syncEnd = SafeCast.toUint32(block.timestamp);
        syncStart = SafeCast.toUint32(block.timestamp);

        _transfer(address(0), gov_, initialSupply_);
        __AccessControlDefaultAdminRules_init(0, gov_);
        _grantRole(REBASER_ROLE, gov_);
        _grantRole(MINTER_ROLE, gov_);
        _grantRole(PAUSER_ROLE, gov_);


        _grantRole(BURNER_ROLE, burner);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(MINTER_ROLE, rebaser);
        _grantRole(REBASER_ROLE, rebaser);

    }


    /**
    * @notice Sets transfer pause status 
    * @dev Necessary incase an operator messes up claim timing
    * or oracle is wrong
    */
    function pauseTransfer(bool status) external onlyRole(PAUSER_ROLE) returns (bool) {
        transferPaused = status;
        return true;
    }

    /**
    * @notice Sets mint pause status 
    */
    function pauseMint(bool status) external onlyRole(PAUSER_ROLE) returns (bool) {
        mintPaused = status;
        return true;
    }

    /**
    * @notice Sets burn pause status
    */
    function pauseBurn(bool status) external onlyRole(PAUSER_ROLE) returns (bool) {
        burnPaused = status;
        return true;
    }

    /**
    * @notice Sets rebase pause status
    */
    function pauseRebase(bool status) external onlyRole(PAUSER_ROLE) returns (bool) {
        rebasePaused = status;
        return true;
    }


    /**`
    * @notice Mints new tokens, increasing totalSupply, initSupply, and a users balance.
    * @dev Limited to onlyMinter modifier
    */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) notMintPaused returns (bool) {
        _mint(to, amount);
        return true;
    }

    /**
     * Mint functions
     * @param to Address to mint to
     * @param amount Amount to mint
     */
    function _mint(address to, uint256 amount) internal {

        _transfer(address(0), to, amount);

        emit Mint(to, amount);
    }

    /**
     * Internal function to handle transfers/mints/burns
     * @param from address to decrease balance
     * @param to address to increase balance
     * @param amount balance delta
     * @dev _transferVotingRights handles the checkpointing functionality
     * within `VotesUpgradeable`. If the `to` or `from` address is zero address
     * then the function will increment/decrement total supply depending on whether
     * it is a mint or a burn. If it is just a normal transfer then it will append a new 
     * checkpoint to the `from` address and the `to` address with their new balances. Rewards
     * are not high enough to have to worry about preSyncSupply underflowing. 
     */
    function _transfer(address from, address to, uint256 amount) internal {

        uint256 shares = _balanceToShares(amount);

        if (from == address(0)) {
            preSyncSupply += SafeCast.toUint96(amount);
        } else if (to == address(0)) {
            preSyncSupply -= SafeCast.toUint96(amount);
        }

        _transferVotingUnits(from, to, shares);

        emit Transfer(from, to, amount);
    }

    /**
    * @dev Transfer tokens to a specified address.
    * @param to The address to transfer to.
    * @param value The amount to be transferred.
    * @return True on success, false otherwise.
    */
    function transfer(address to, uint256 value) external notTransferPaused returns (bool) {

        _transfer(msg.sender, to, value);

        return true;
    }

    /**
     * Burn tokens
     * @param value Amount to burn
     * @param refundee Address to burn from
     */
    function burn(uint256 value, address refundee) external notBurnPaused onlyRole(BURNER_ROLE) returns (bool) {
        _burn(value, refundee);
        return true;
    } 

    /**
     * Burn tokens
     * @param value Amount to burn
     * @param refundee Address to burn from
     * @dev Only the burner contract can burn tokens.
     */
    function _burn(uint256 value, address refundee) internal {
        _transfer(refundee, address(0), value);
    }
    /**
    * @dev Transfer tokens from one address to another.
    * @param from The address you want to send tokens from.
    * @param to The address you want to transfer to.
    * @param value The amount of tokens to be transferred.
    */
    function transferFrom(address from, address to, uint256 value) external notTransferPaused returns (bool) {
        // decrease allowance
        _allowedBalances[from][msg.sender] = _allowedBalances[from][msg.sender] - value;

        _transfer(from, to, value);

        return true;
    }

    /**
    * @param who The address to query.
    * @return The balance of the specified address.
    */
    function balanceOf(address who) external view returns (uint256) {
        return _balanceOf(who);
    }

    /**
     * Queries balance of address
     * @param who The address to query
     * @dev This retrieves the underlying shares from `VotesUpgradeable`
     * which is the value of the latest balance checkpoint. It is then converted
     * to actual balance
     */
    function _balanceOf(address who) internal view returns (uint256) {
        return _sharesToBalance(super.getVotes(who));
    }

    /** @notice Currently returns the internal storage amount
    * @param who The address to query.
    * @return The underlying shares of the specified address.
    */
    function sharesOf(address who) external view returns (uint256) {
        return super.getVotes(who);
    }

    /**
     * @dev Function to check the amount of tokens that an owner has allowed to a spender.
     * @param owner_ The address which owns the funds.
     * @param spender The address which will spend the funds.
     * @return The number of tokens still available for the spender.
     */
    function allowance(address owner_, address spender) external view returns (uint256) {
        return _allowedBalances[owner_][spender];
    }

    /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of
     * msg.sender. This method is included for ERC20 compatibility.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     */
    function approve(address spender, uint256 value) external returns (bool) {
        _allowedBalances[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /**
     * Function called by rebaser that will initiate a new rewards distribution
     * @param epoch Used for event
     * @param newSupply Value to set the new supply to
     * @param syncInterval Time for the token to reach the `newSupply`
     * If the newSupply is less than current supply (a slash), we will set this as the newSupply
     * without an interval. If the supply exceeds, then we will set the preSyncSupply to the current 
     * supply and adjust rewardsToSync to sync the delta over the syncInterval. Interruptions to a sync
     * interval can be handled fine, but the Rebaser can only rebase every syncInterval in any case.  
     */
    function syncSupply(uint256 epoch, uint256 newSupply, uint256 syncInterval) external onlyRole(REBASER_ROLE) notRebasePaused returns (bool) {
        uint256 currentSupply = _totalSupply();

        if (newSupply < currentSupply) {
            preSyncSupply = SafeCast.toUint96(newSupply);
            rewardsToSync = 0;
            syncEnd       = SafeCast.toUint32(block.timestamp);
            syncStart     = SafeCast.toUint32(block.timestamp);
        } else {
            preSyncSupply = SafeCast.toUint96(currentSupply);
            rewardsToSync = SafeCast.toUint96(newSupply - currentSupply);
            syncEnd       = SafeCast.toUint32(block.timestamp + syncInterval);
            syncStart     = SafeCast.toUint32(block.timestamp);
        }

        emit Rebase(epoch, currentSupply, newSupply, syncInterval);

        return true;
    }

    /**
     * Converts from actual balance to underlying shares
     * @param balance Balance value to convert
     * @dev Keep in mind that one unit of balance is 18 decimals 
     * while one unit of share is 24 decimals. 
     */
    function balanceToShares(uint256 balance) external view returns (uint256) {
        return _balanceToShares(balance);
    }

    /**
     * Converts from underlying shares to actual balance
     * @param shares Share value to convert
     * @dev Keep in mind that one unit of balance is 18 decimals 
     * while one unit of share is 24 decimals. 
     */
    function sharesToBalance(uint256 shares) external view returns (uint256) {
        return _sharesToBalance(shares);
    }

    /**
     * @param balance Balance value to convert
     * @dev We divide total shares by total supply to get the balance/shares conversion factor.
     * We use raw total supply to avoid intermediate rounding error.
     */
    function _balanceToShares(uint256 balance) internal view returns (uint256) {
        uint256 totalShares = _getTotalSupply();
        return totalShares == 0 ? balance * balanceToShareDecimals :  balance.mulDivDown(totalShares * balanceToShareDecimals,  _totalSupplyRaw()) ; //mulDivDown(totalShares * 10**18, _totalSupplyRaw());
    }

    /**
     * @param shares Share value to convert
     * @dev We divide total supply by total shares to get the shares/balance conversion factor.
     * Raw total supply used to avoid intermediate rounding error. 
     */
    function _sharesToBalance(uint256 shares) internal view returns (uint256) {
        uint256 totalShares = _getTotalSupply();
        return totalShares == 0 ? shares / balanceToShareDecimals : shares.mulDivDown( _totalSupplyRaw(), totalShares * balanceToShareDecimals);        //.mulDivDown(_totalSupplyRaw(),totalShares * 10**24);
    }

    /**
     * Gives the amount of balance (18 decimals) per share (24 decimals)
     */
    function balancePerShare() external view returns (uint256) {
        return _sharesToBalance(shareDecimals);
    }

    /**
     * Perform rescues in case they are needed
     * @param token token address
     * @param to recipient address
     * @param amount amount
     */
    function rescueTokens(address token, address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        IERC20(token).transfer(to, amount);
        return true;
    }

    /**
     * Returns the components to calculate the total supply
     * @dev This function allows us to calculate stuff with total
     * supply while avoiding intermediate rounding error. The actual 
     * total supply is preSyncSupply + rewardsNumerator/rewardsDenominator
     * We return the components of the fraction separately. This function 
     * also linearly increases the totalSupply over the syncInterval so rewards
     * are distributed monotonically
     * @return preSyncSupply
     * @return rewardsNumerator
     * @return rewardsDenominator
     */
    function _totalSupplyComponents() internal view returns (uint256, uint256, uint256) {
        uint32 blockTimestamp = SafeCast.toUint32(block.timestamp);
        uint32 syncEnd_ = syncEnd;
        uint32 syncStart_ = syncStart;
        uint96 preSyncSupply_ = preSyncSupply;
        uint96 rewardsToSync_ = rewardsToSync;
        
        if (blockTimestamp >= syncEnd_) {
            return (preSyncSupply_, rewardsToSync_, 1);
        }

        if (blockTimestamp == syncStart_) {
            return (preSyncSupply_, 0 ,1);
        }

        uint256 rewardsNumerator = uint256(rewardsToSync_) * (blockTimestamp - syncStart_);
        uint256 rewardsDenominator = (syncEnd_ - syncStart_);
        return (preSyncSupply_, rewardsNumerator, rewardsDenominator);
    }

    /**
     * @dev Returns total supply to 24 decimals for share calculations
     */
    function _totalSupplyRaw() internal view returns (uint256) {
        (uint256 a, uint256 b, uint256 c) = _totalSupplyComponents();
        return a*balanceToShareDecimals + b.mulDivDown(balanceToShareDecimals, c);
    }

    function totalSupplyRaw() external view returns (uint256) {
        return _totalSupplyRaw();
    }

    /**
     * @dev returns the total supply to 18 deciamls for public consumption
     */
    function _totalSupply() internal view returns (uint256) {
        return _totalSupplyRaw() / balanceToShareDecimals;
    }

    /**
     * Public getter for total supply of stFLIP
     */
    function totalSupply() external view returns (uint256) {
        return _totalSupply();
    }

    /**
     * Public getter for total shares of stFLIP
     */
    function totalShares() external view returns (uint256) {
        return _getTotalSupply();
    }

    /**
     * Overriding the clock set in `VotesUpgradeable` since
     * GovernorOmega uses timestamp
     */
    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    function balanceOf(address account, uint256 timepoint) external view returns (uint256) {
        return getPastVotes(account, timepoint);
    }

    function getVotes(address account, uint256 timepoint) external view returns (uint256) {
        return getPastVotes(account, timepoint);
    }

    function totalSupplyAt(uint256 timepoint) external view returns (uint256) {
        return getPastTotalSupply(timepoint);
    }

    function newSnapshotTime(uint256 snapshot) external onlyRole(GOVERNOR_ROLE) returns (bool) {
        lastSnapshotTime = SafeCast.toUint32(snapshot);
        return true;
    }

    function delegate(address) external {}
}





