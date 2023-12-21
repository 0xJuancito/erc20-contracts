//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";

/// Insufficient privileges. 
error Forbidden();

/// Invalid Parameters. 
error BadUserInput();

/// Invalid Address. 
/// @param addr invalid address.
error InvalidAddress(address addr);

/// Value too large. Maximum `maximum` but `attempt` provided.
/// @param attempt balance available.
/// @param maximum maximum value.
error ValueOverflow(uint256 attempt, uint256 maximum); 

/// Value too large. Maximum `maximum` but `attempt` provided.
/// @param attempt balance available.
/// @param maximum maximum value.
error AllowanceOverflow(uint256 attempt, uint256 maximum); 

/// @title Tales of Elleria: Ellerium ERC20
/// @author Wayne (Ellerian Prince)
/// @notice Tales of Elleria's In-Game Token.
contract ElleriumTokenERC20v2 is Context, IERC20, IERC20Metadata, Ownable {

    /// @dev Mapping from user address to their balances.
    mapping(address => uint256) private _balances;

    /// @dev Mapping from user address to mapping of allowances of each approved address.
    mapping(address => mapping(address => uint256)) private _allowances;

    /// @dev Total Supply of the Token
    uint256 private _totalSupply;

    /// @dev Name of the Token
    string private _name = "Ellerium";

    /// @dev Symbol of the Token
    string private _symbol = "ELM";

    /// @dev Mapping for addresses approved to mint (bridge and LP).
    mapping (address => bool) private _approvedAddresses;

    /// @dev Mints initial sum of Tokens to the deployer for setting up.
    constructor() {
        // 375,550 $ELM allocated into the LP.
        // 500,000 $ELM allocated into team vest (5 years starting 01/01/2023).
        // 125,000 + 175,000 $ELM allocated into TreasureDAO vest. (5 years starting 01/10/2022).
        _mint(_msgSender(), (375550 + 500000 + 300000) * 1e18); 
        _approvedAddresses[_msgSender()] = true;
    }

    /// @dev (Owner Only) Sets approved addresses for custom mechanisms (Token mint from stake/bridge).
    /// @param _address Address affected.
    /// @param _isAllowed Is Approved?
    function setApprovedAddress(address _address, bool _isAllowed) external onlyOwner {
        _approvedAddresses[_address] = _isAllowed;
        emit ApprovedAddressChange(_address, _isAllowed);
    }

    /// @notice Returns the name of the Token.
    /// @return Name of the token.
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /// @notice Returns the symbol of the Token.
    /// @return Symbol of the token.
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /// @notice Returns the number of decimals used to get its user representation.
    /// For example, if `decimals` equals `2`, a balance of `505` tokens should
    /// be displayed to a user as `5,05` (`505 / 10 ** 2`).
    /// @return Decimals Used.
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /// @notice Returns the total supply of the Token. See {IERC20-totalSupply}.
    /// @return Total Supply.
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /// @notice Returns the balances of an address. See {IERC20-balanceOf}.
    /// @param account Address to retrieve balances for.
    /// @return Balance of account.
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    
    /// @notice Transfers an amount of tokens to a recipient. See {IERC20-transfer}.
    /// @param recipient Address to receive Tokens.
    /// @param amount Amount of tokens.
    /// @return True if success.
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /// @notice Returns allowances for an address. See {IERC20-allowance}.
    /// @param owner Address with the allowances.
    /// @param spender Address that does the spending.
    /// @return Allowance of the spender for owner.
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }    

    /// @notice Approves allowances for an address. See {IERC20-approve}.
    /// @param spender Address that can spend on sender's behalf.
    /// @param amount Amount to approve for spending.
    /// @return True if success.
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /// @notice See {IERC20-transferFrom}.
    /// Emits an {Approval} event indicating the updated allowance. This is not
    /// required by the EIP. See the note at the beginning of {ERC20}.
    /// @param sender Address sending tokens.
    /// @param recipient Address receiving tokens.
    /// @param amount Amount transferred.
    /// @return True if success.
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        if (amount > currentAllowance) {
            revert AllowanceOverflow(amount, currentAllowance);
        }

        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        _transfer(sender, recipient, amount);

        return true;
    }

    /// @notice Atomically increases the allowance granted to `spender` by the caller.
    /// Emits an {Approval} event indicating the updated allowance.
    /// @param spender Address of the spender for the message sender.
    /// @param addedValue Value to add to allowance.
    /// @return True if success.
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    /// @notice Atomically decreases the allowance granted to `spender` by the caller.
    /// Emits an {Approval} event indicating the updated allowance.
    /// @param spender Address of the spender for the message sender.
    /// @param subtractedValue Value to decrease from allowance.
    /// @return True if success.
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];

        if (subtractedValue > currentAllowance) {
            revert AllowanceOverflow(subtractedValue, currentAllowance);
        }

        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }


    /// @notice Moves `amount` of tokens from `sender` to `recipient`.
    /// This internal function is equivalent to {transfer}, with a blacklist function
    /// to prevent bots from swapping tokens automatically after LP is added to. 
    /// Emits a {Transfer} event.
    /// @param sender Address sending tokens.
    /// @param recipient Address receiving tokens.
    /// @param amount Amount transferred.
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        if (sender == address(0)) {
            revert InvalidAddress(sender);
        }

        uint256 senderBalance = _balances[sender];

        if (amount > senderBalance) {
            revert ValueOverflow(amount, senderBalance);
        }

        unchecked {
            _balances[sender] = senderBalance - amount;
        }

        if (recipient == address(0)) {
            // Demint for burn transactions.
            _totalSupply -= amount;    
        } else {
            // Only increment balances for a non-zero address.
            _balances[recipient] += amount;
        }
        
        emit Transfer(sender, recipient, amount);
    }

    /// @notice Creates `amount` tokens and assigns them to `account`, increasing the total supply.
    /// Emits a {Transfer} event.
    /// @param account Address receiving tokens.
    /// @param amount Amount of tokens assigned.
    function _mint(address account, uint256 amount) internal {
        if (account == address(0)) {
            revert InvalidAddress(account);
        }

        _totalSupply += amount;
        _balances[account] += amount;

        emit Transfer(address(0), account, amount);
    }

    /// @notice (Approved Address Only) Mint Tokens (Bridging/Staking Rewards).
    /// Emits a {Transfer} event.
    /// @param account Address receiving tokens.
    /// @param amount Amount of tokens assigned.
    function mint(address account, uint256 amount) external {
        if (!_approvedAddresses[_msgSender()]) {
            revert InvalidAddress(_msgSender());
        }

        _mint(account, amount);
    }

    /// @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
    /// This internal function is equivalent to `approve`, and can be used to
    /// e.g. set automatic allowances for certain subsystems, etc.
    /// Emits an {Approval} event.
    /// @param owner Address with the allowances. Cannot be the zero address.
    /// @param spender Address that will be spending on owner's behalf. Cannot be the zero address.
    /// @param amount Amount to approve for spending.
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        if (owner == address(0) || spender == address(0)) {
            revert InvalidAddress(address(0));
        }

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

  /// @notice Event emitted when an address' blacklist status changes.
  /// @param addr The address affected.
  /// @param isBlacklisted Is blacklisted?
  event Blacklist(address addr, bool isBlacklisted);

  /// @notice Event emitted when an approved address' status changes.
  /// @param addr The address affected.
  /// @param isApproved Is approved?
  event ApprovedAddressChange(address addr, bool isApproved);
}