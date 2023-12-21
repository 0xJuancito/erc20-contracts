// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

contract FARMSENT is
    Initializable,
    UUPSUpgradeable,
    ERC20Upgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    ERC20BurnableUpgradeable
{
    uint8 private decimal;

    mapping(address => bool) public _whitelist;
    mapping(address => bool) public _blacklist;

    bool public enableWhiteList_;

    event BlackListed(address indexed account);
    event RemovedFromBlackListed(address indexed account);
    event AddMultipleAccountToBlacklist(address[] indexed accounts);
    event WhiteListed(address indexed account);
    event RemovedFromWhiteListed(address indexed account);
    event AddMultipleAccountToWhitelist(address[] indexed accounts);
    event EnableOrDisableWhitelist(bool IsWhitelist);

    function initialize(
        string memory _name,
        string memory _symbol,
        uint8 _decimal,
        uint256 _totalSupply
    ) public initializer {
        require(bytes(_name).length != 0, "Name is required");
        require(bytes(_symbol).length != 0, "Symbol is required");
        require(_decimal > 0 && _decimal < 19, "Decimal is required and cannot be more than 18");
        require(_totalSupply > 0, "Total Supply is required");
        __ERC20Burnable_init_unchained();
        __ERC20_init_unchained(_name, _symbol);
        __Pausable_init_unchained();
        __Ownable_init_unchained();

        decimal = _decimal;
        _mint(msg.sender, _totalSupply);
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for display purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view override returns (uint8) {
        return decimal;
    }

    /**
        @dev Pause the contract (stopped state) by owner
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
        @dev Unpause the contract (normal state) by owner
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    function mint(uint256 amount) external onlyOwner {
        _mint(msg.sender, amount);
    }

    /**
     * @dev For authorizing the uups upgrade
     */
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        if (enableWhiteList_) {
            require(_whitelist[msg.sender], "Account is not whitelisted");
        }
        require(!_blacklist[msg.sender], "Account is blacklisted");
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        if (enableWhiteList_) {
            require(_whitelist[msg.sender], "Account is not whitelisted");
        }
        require(!_blacklist[msg.sender], "Account is blacklisted");
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
    @dev owner can enable the whitelist
     */

    function enableOrDisableWhitelist(bool _isWhitelist) external onlyOwner {
        enableWhiteList_ = _isWhitelist;
        emit EnableOrDisableWhitelist(_isWhitelist);
    }

    /**
     * @dev Adding a account to Whitelisting
     * @param _beneficiary address of the account.
     */
    function addToBlacklist(address _beneficiary) external onlyOwner {
        require(_beneficiary != address(0), "Account cant be zero address");
        require(!_blacklist[_beneficiary], "Account is blacklisted");
        _blacklist[_beneficiary] = true;
        emit BlackListed(_beneficiary);
    }

    /**
     * @dev Adding multiple account to blacklisting
     * @param _beneficiers address of the account.
     */
    function addMultipleAccountToBlacklist(
        address[] calldata _beneficiers
    ) external onlyOwner {
        {
            for (uint256 i = 0; i < _beneficiers.length; i++) {
                if (
                    !_blacklist[_beneficiers[i]] &&
                    _beneficiers[i] != address(0)
                ) _blacklist[_beneficiers[i]] = true;
            }
        }

        emit AddMultipleAccountToBlacklist(_beneficiers);
    }

    /**
     * @dev Removing account to blacklisting
     * @param _beneficiary address of the account.
     */
    function removeFromBlacklist(address _beneficiary) external onlyOwner {
        _blacklist[_beneficiary] = false;
        emit RemovedFromBlackListed(_beneficiary);
    }

    /**
     * @dev Adding a account to Whitelisting
     * @param _beneficiary address of the account.
     */
    function addToWhitelist(address _beneficiary) external onlyOwner {
        require(_beneficiary != address(0), "Account cant be zero address");
        require(!_whitelist[_beneficiary], "Account is already whitelisted");
        _whitelist[_beneficiary] = true;
        emit WhiteListed(_beneficiary);
    }

    /**
     * @dev Adding multiple account to Whitelisting
     * @param _beneficiers address of the account.
     */
    function addMultipleAccountToWhitelist(
        address[] calldata _beneficiers
    ) external onlyOwner {
        for (uint256 i = 0; i < _beneficiers.length; i++) {
            if (
                !_whitelist[_beneficiers[i]] && _beneficiers[i] != address(0)
            ) {
                _whitelist[_beneficiers[i]] = true;
            }
        }
        emit AddMultipleAccountToWhitelist(_beneficiers);
    }

    /**
     * @dev Removing account to Whitelisting
     * @param _beneficiary address of the account.
     */
    function removeFromWhitelist(address _beneficiary) external onlyOwner {
        _whitelist[_beneficiary] = false;
        emit RemovedFromWhiteListed(_beneficiary);
    }
}
