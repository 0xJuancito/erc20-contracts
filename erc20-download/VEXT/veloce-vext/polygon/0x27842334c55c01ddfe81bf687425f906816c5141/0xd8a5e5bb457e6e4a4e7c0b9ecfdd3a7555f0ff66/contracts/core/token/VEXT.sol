// SPDX-License-Identifier: agpl-3.0 MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "./ERC20VotesUpgradeable.sol";
import "../../interfaces/IVextToken.sol";
import "../../interfaces/IAccess.sol";
import "../security/AbstractSystemPause.sol";

contract VEXT is
    Initializable,
    ERC20Upgradeable,
    PausableUpgradeable,
    ERC20VotesUpgradeable,
    AbstractSystemPause,
    IVextToken
{
    /* ========== STATE VARIABLES ========== */

    /// Access interface
    IAccess access;
    /// total accounts
    uint256 totalAccounts;
    /// max supply
    uint256 public maxSupply;

    /* ========== REVERT STATEMENTS ========== */

    error ExceedsMaxSupply(uint256 value, uint256 maxSupply);

    /* ========== MODIFIERS ========== */

    /**
     @dev this modifier calls the Access contract. Reverts if caller does not have role
     */

    modifier onlyTokenRole() {
        access.onlyTokenRole(msg.sender);
        _;
    }

    /* ========== CONSTRUCTOR ========== */

    function initialize(
        address _accessAddress,
        address _systemPauseAddress,
        uint256 _maximumSupply
    ) public initializer {
        __ERC20_init("Veloce", "VEXT");
        __Pausable_init();
        __ERC20Permit_init("Veloce");
        __ERC20Votes_init();
        require(
            _accessAddress != address(0) && _systemPauseAddress != address(0),
            "Address zero input"
        );
        access = IAccess(_accessAddress);
        system = ISystemPause(_systemPauseAddress);
        maxSupply = _maximumSupply;
    }

    /* ========== EXTERNAL ========== */

    /**
    @dev this function is for minting tokens. 
    Callable when system is not paused and contract is not paused. Callable by executive.
     */
    function mint(
        address to,
        uint256 amount
    ) external override whenNotPaused whenSystemNotPaused onlyTokenRole {
        if (totalSupply() + amount > maxSupply)
            revert ExceedsMaxSupply(totalSupply() + amount, maxSupply);

        if (amount != 0) _increaseTotalAccounts(to);
        super._mint(to, amount);
    }

    /**
    @dev this function is for burning tokens. 
    Callable when system is not paused and contract is not paused. Callable by executive.
     */

    function burn(
        address from,
        uint256 amount
    ) external virtual override whenNotPaused whenSystemNotPaused {
        require(from == msg.sender, "User can only burn owned tokens");
        super._burn(from, amount);
        if (amount != 0) _decreaseTotalAccounts(from);
    }

    /**
     * @dev function to pause contract only callable by admin
     */
    function pauseContract() external virtual override onlyTokenRole {
        _pause();
    }

    /**
     * @dev function to unpause contract only callable by admin
     */
    function unpauseContract() external virtual override onlyTokenRole {
        _unpause();
    }

    /**
    @dev this function returns the total accounts
    @return uint256 total accounts that own VEXT
     */

    function getTotalAccounts() external view override returns (uint256) {
        return totalAccounts;
    }

    /* ========== PUBLIC ========== */

    /**
    @dev this function is for transferring tokens. 
    Callable when system is not paused and contract is not paused.
    @return bool if the transfer was successful
     */

    function transfer(
        address to,
        uint256 amount
    ) public virtual override(ERC20Upgradeable, IVextToken) returns (bool) {
        if (amount != 0) _increaseTotalAccounts(to);
        super.transfer(to, amount);
        if (amount != 0) _decreaseTotalAccounts(msg.sender);
        return true;
    }

    /**
    @dev this function is for third party transfer of tokens. 
    Callable when system is not paused and contract is not paused.
    @return true if the transfer was successful
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override(ERC20Upgradeable, IVextToken) returns (bool) {
        if (amount != 0) _increaseTotalAccounts(to);
        super.transferFrom(from, to, amount);
        if (amount != 0) {
            _decreaseTotalAccounts(from);
        }
        return true;
    }

    /**
    @dev approve function to approve spender with amount. 
    Can be called when system and this contract is unpaused.
    @param spender. The approved address. 
    @param amount. The amount spender is approved for. 
    @return true if the approval was successful
     */
    function approve(
        address spender,
        uint256 amount
    ) public virtual override(ERC20Upgradeable, IVextToken) returns (bool) {
        return super.approve(spender, amount);
    }

    /**
    @dev this function returns the allowance for spender.
    @param owner. The owner of approved tokens. 
    @param spender. The amount spender is approved for. 
    @return uint256. The amount spender is approved for
     */

    function allowance(
        address owner,
        address spender
    )
        public
        view
        virtual
        override(ERC20Upgradeable, IVextToken)
        returns (uint256)
    {
        return super.allowance(owner, spender);
    }

    /**
    @dev this function returns the balance of account
    @param account. The account to return balance for
    @return balance 
     */

    function balanceOf(
        address account
    )
        public
        view
        virtual
        override(ERC20Upgradeable, IVextToken)
        returns (uint256)
    {
        return super.balanceOf(account);
    }

    /**
    @dev this function returns the total supply
     */

    function totalSupply()
        public
        view
        virtual
        override(ERC20Upgradeable, IVextToken)
        returns (uint256)
    {
        return super.totalSupply();
    }

    /**
    @dev this function returns past votes for a user at a specified block number
    @param account. The account to get past votes for
    @param blockNumber. The block number checkpoint to get past votes
    @return the past votes for a user at a specified block number
     */
    function getPastVotes(
        address account,
        uint256 blockNumber
    )
        public
        view
        virtual
        override(IVextToken, ERC20VotesUpgradeable)
        returns (uint256)
    {
        return super.getPastVotes(account, blockNumber);
    }

    function getProposalVotes(
        address account,
        uint256 blockNumber
    ) external view virtual override returns (uint256) {
        return _getProposalVotes(account, blockNumber);
    }

    /**
    @dev this function returns the user's votes
    @param account. The account to return votes for
    @return the user's total votes
     */

    function getVotes(
        address account
    )
        public
        view
        virtual
        override(IVextToken, ERC20VotesUpgradeable)
        returns (uint256)
    {
        return super.getVotes(account);
    }

    /**
     * @dev Returns the address currently delegated for the specified account.
     * Overrides the `delegates` function in `IVextToken` and `ERC20VotesUpgradeable`.
     * @param account The address of the account to check.
     * @return The address currently delegated for the specified account.
     */
    function delegates(
        address account
    )
        public
        view
        virtual
        override(IVextToken, ERC20VotesUpgradeable)
        returns (address)
    {
        return super.delegates(account);
    }

    function decimals()
        public
        view
        virtual
        override(ERC20Upgradeable, IVextToken)
        returns (uint8)
    {
        return super.decimals();
    }

    function getCheckpointBlockNumber(
        address account,
        uint32 pos
    ) external view virtual override returns (uint32) {
        Checkpoint memory checkpoint = checkpoints(account, pos);

        return checkpoint.fromBlock;
    }

    /* ========== INTERNAL ========== */

    /**
    @dev internal function beforeTokenTransfer
     */

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._beforeTokenTransfer(from, to, amount);
    }

    /**
    @dev internal function afterTokenTransfer
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        super._afterTokenTransfer(from, to, amount);
    }

    /**
    @dev internal function burn
     */
    function _burn(
        address from,
        uint256 amount
    ) internal virtual override(ERC20VotesUpgradeable, ERC20Upgradeable) {
        super._burn(from, amount);
    }

    /**
    @dev internal function mint
     */

    function _mint(
        address account,
        uint256 amount
    ) internal virtual override(ERC20VotesUpgradeable, ERC20Upgradeable) {
        super._mint(account, amount);
    }

    /**
    @dev internal function which increases total accounts holding VEXT
    @param _account. It checks that account is not address zero and account's balance is zero. 
     */

    function _increaseTotalAccounts(address _account) internal {
        if (_account != address(0) && balanceOf(_account) == uint256(0))
            ++totalAccounts;

        emit TotalAccounts(totalAccounts);
    }

    /**
    @dev internal function which decreases total accounts holding VEXT
    @param _account. It checks that account is not address zero and account's balance is zero. 
     */

    function _decreaseTotalAccounts(address _account) internal {
        if (_account != address(0) && balanceOf(_account) == uint256(0))
            --totalAccounts;

        emit TotalAccounts(totalAccounts);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
