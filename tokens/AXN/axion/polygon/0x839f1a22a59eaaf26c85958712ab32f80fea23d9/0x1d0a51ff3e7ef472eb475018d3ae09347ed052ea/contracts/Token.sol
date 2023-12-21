// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;
/** OpenZeppelin Dependencies Upgradeable */
import '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol';
/** OpenZepplin non-upgradeable Swap Token (hex3t) */
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
/** Local Interfaces */
import './interfaces/IToken.sol';
import './interfaces/IVentureCapital.sol';
import './abstracts/Pauseable.sol';

contract Token is ERC20Upgradeable, Pauseable {
    using SafeERC20 for IERC20;
    //** Role Variables */
    bytes32 public constant MINTER_ROLE = keccak256('MINTER_ROLE');
    //** Tax */
    mapping(address => bool) public _isExcludedFromFee; // done
    uint8 sellTax;
    // Protection */
    mapping(address => uint256) public _timeOfLastTransfer;
    mapping(address => bool) public _blacklist;
    bool public timeLimited;
    mapping(address => bool) public pairs;
    mapping(address => bool) public routers;
    uint256 public timeBetweenTransfers;

    // Total frozen amount from sales tax
    uint256 public totalFrozen;
    address venture;

    // Black list for bots */
    modifier isBlackedListed(address sender, address recipient) {
        require(_blacklist[sender] == false, 'ERC20: Account is blacklisted from transferring');
        _;
    }

    // Role Modifiers */
    modifier onlyMinter() {
        require(hasRole(MINTER_ROLE, _msgSender()), 'Caller is not a minter');
        _;
    }

    /** End initialize Functions */

    function getMinterRole() external pure returns (bytes32) {
        return MINTER_ROLE;
    }

    function getBurnerRole() external pure returns (bytes32) {
        return MINTER_ROLE;
    }

    function mint(address to, uint256 amount) external onlyMinter {
        _mint(to, amount);
    }

    function bulkMint(address[] calldata userAddresses, uint256[] calldata amounts)
        external
        onlyManager
    {
        for (uint256 idx = 0; idx < userAddresses.length; idx = idx + 1) {
            _mint(userAddresses[idx], amounts[idx]);
        }
    }

    function burn(address from, uint256 amount) external onlyMinter {
        _burn(from, amount);
    }

    function managerTransfer(
        address to,
        address from,
        uint256 amount
    ) external onlyManager {
        _transfer(from, to, amount);
    }

    function safeRecover(
        address recoverFor,
        address tokenToRecover,
        uint256 amount
    ) external onlyManager {
        IERC20(tokenToRecover).safeTransfer(recoverFor, amount);
    }

    // protection
    function isTimeLimited(address sender, address recipient) internal {
        if (timeLimited && _whitelist[recipient] == false && _whitelist[sender] == false) {
            address toDisable = sender;
            if (pairs[sender] == true) {
                toDisable = recipient;
            } else if (pairs[recipient] == true) {
                toDisable = sender;
            }

            if (pairs[toDisable] == true || routers[toDisable] == true || toDisable == address(0))
                return; // Do nothing as we don't want to disable router

            if (_timeOfLastTransfer[toDisable] == 0) {
                _timeOfLastTransfer[toDisable] = block.timestamp;
            } else {
                require(
                    block.timestamp - _timeOfLastTransfer[toDisable] > timeBetweenTransfers,
                    'ERC20: Time since last transfer must be greater then time to transfer'
                );
                _timeOfLastTransfer[toDisable] = block.timestamp;
            }
        }
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        whenNotPaused(msg.sender)
        isBlackedListed(msg.sender, recipient)
        returns (bool)
    {
        isTimeLimited(msg.sender, recipient);
        (uint256 taxed, uint256 amountLeft) = getTaxAmount(msg.sender, recipient, amount);
        if (taxed > 0) {
            uint256 toStakers = taxed / 2;
            uint256 toDead = taxed - toStakers;

            super.transfer(0x000000000000000000000000000000000000dEaD, toDead);
            super.transfer(venture, toStakers);

            totalFrozen += toDead;
            IVentureCapital(venture).updateTokenPricePerShareAxn(toStakers);
        }
        return super.transfer(recipient, amountLeft);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override whenNotPaused(sender) isBlackedListed(sender, recipient) returns (bool) {
        isTimeLimited(sender, recipient);
        (uint256 taxed, uint256 amountLeft) = getTaxAmount(sender, recipient, amount);
        if (taxed > 0) {
            uint256 toStakers = taxed / 2;
            uint256 toDead = taxed - toStakers;

            super.transferFrom(sender, 0x000000000000000000000000000000000000dEaD, toDead);
            super.transferFrom(sender, venture, toStakers);

            totalFrozen += toDead;
            IVentureCapital(venture).updateTokenPricePerShareAxn(toStakers);
        }

        super.transferFrom(sender, recipient, amountLeft);
        return true;
    }

    /** @dev get tax 
        @param sender {address}
        @param recipient {address}
        @param amount {uint256}
    */
    function getTaxAmount(
        address sender,
        address recipient,
        uint256 amount
    ) internal view returns (uint256 taxed, uint256 amountLeft) {
        if (pairs[recipient] == true && _isExcludedFromFee[sender] == false) {
            // Sell
            taxed = (amount * uint256(sellTax)) / 100;
            amountLeft = amount - taxed;
        } else {
            // Everything else.
            taxed = 0;
            amountLeft = amount;
        }
    }

    function getTax() external view returns (uint8) {
        return sellTax;
    }

    /** Exclude 
        Description: When an account is excluded from fee, we remove fees then restore fees
        @param account {address}
     */
    function setExcludeForAccount(address account, bool exclude) external onlyManager {
        _isExcludedFromFee[account] = exclude;
    }

    /** @dev set venture {onlyOwner}
        @param _venture {address}
     */
    function setVenture(address _venture) external onlyManager {
        venture = _venture;
    }

    /** @dev set sell tax {onlyOwner}
        @param tax {uint8}
     */
    function setSellTax(uint8 tax) external onlyManager {
        sellTax = tax;
    }

    function setTimeLimited(bool _timeLimited) external onlyManager {
        timeLimited = _timeLimited;
    }

    function setTimeBetweenTransfers(uint256 _timeBetweenTransfers) external onlyManager {
        timeBetweenTransfers = _timeBetweenTransfers;
    }

    function setPair(address _pair, bool _isPair) external onlyManager {
        pairs[_pair] = _isPair;
    }

    function setRouter(address _router, bool _isRouter) external onlyManager {
        routers[_router] = _isRouter;
    }

    function setBlackListedAddress(address account, bool blacklisted) external onlyManager() {
        _blacklist[account] = blacklisted;
    }
}
