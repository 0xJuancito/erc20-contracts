// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

abstract contract ERC20Detailed is Initializable, IERC20Upgradeable {
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    function __ERC20Detailed_init(
        string memory name,
        string memory symbol,
        uint8 decimals
    ) internal onlyInitializing {
        _name = name;
        _symbol = symbol;
        _decimals = decimals;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }
}

abstract contract ERC20VestingUpgradeable is Initializable, ERC20Detailed, OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;
    using AddressUpgradeable for address;

    bool public inVestingPeriod;

    uint256 public percentage;
    uint256 public constant PAYMENT_PERIOD = 86400; // 1 day

    struct Vesting {
        uint256 vestedBalance;
        uint256 released;
        uint256 lastPayment;
        uint256 amountSold;
    }

    mapping(address => Vesting) public vestings;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    function __ERC20Vesting_init(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) internal onlyInitializing {
        __ERC20Detailed_init(_name, _symbol, _decimals);
        __Ownable_init();

        inVestingPeriod = true;

        percentage = 33 * 10**14; // 0.33%
    }

    function endVesting() external virtual onlyOwner {
        inVestingPeriod = false;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return vestings[account].vestedBalance - vestings[account].amountSold;
    }

    /**
     * @dev Getter for the total amount of tokens that is vested for an account.
     */
    function vestedBalanceOf(address account) public view virtual returns (uint256) {
        return vestings[account].vestedBalance - vestings[account].released;
    }

    function balanceAvailable(address account) public view virtual returns (uint256) {
        if (vestings[account].released >= vestings[account].amountSold) {
            return vestings[account].released - vestings[account].amountSold;
        } else {
            return 0;
        }
    }

    /**
     * @dev Amount of token already released
     */
    function released(address account) public view virtual returns (uint256) {
        return vestings[account].released;
    }

    function setVestingPercentage(uint256 _percentage) external onlyOwner {
        require(_percentage > 0, "Percentage must be greater than 0");
        percentage = _percentage;
    }

    /**
     * @dev Release the tokens that have already vested.
     *
     * Emits a {TokensReleased} event.
     */
    function release(address account) public virtual {
        uint256 releasable = vestedAmount(account);
        if (releasable > 0) {
            vestings[account].released += releasable;
            vestings[account].lastPayment = block.timestamp;

            emit TokensReleased(account, releasable);
        }
    }

    /**
     * @dev Calculates the amount of tokens that has already vested. Default implementation is a linear vesting curve.
     */
    function vestedAmount(address account) public view virtual returns (uint256) {
        Vesting memory userVesting = vestings[account];

        uint256 _percentage = ((block.timestamp - userVesting.lastPayment) / PAYMENT_PERIOD) * percentage;
        uint256 amount = (userVesting.vestedBalance * _percentage) / 10**18;

        if (amount >= vestedBalanceOf(account)) {
            amount = vestedBalanceOf(account);
        }

        return amount;
    }

    function setVesting(
        address account,
        uint256 _vestedBalance,
        uint256 _released,
        uint256 _lastPayment,
        uint256 _amountSold
    ) external onlyOwner {
        require(_vestedBalance > 0, "Vested balance must be greater than 0");
        require(_released > 0, "Released balance must be greater than 0");
        require(_lastPayment > 0, "Last payment must be greater than 0");
        require(_lastPayment <= block.timestamp, "Last payment must be in the past");
        require(_amountSold > 0, "Amount sold must be greater than 0");

        vestings[account].vestedBalance = _vestedBalance;
        vestings[account].released = _released;
        vestings[account].lastPayment = _lastPayment;
        vestings[account].amountSold = _amountSold;
    }

    function removeVesting(address account) external onlyOwner {
        vestings[account].vestedBalance = 0;
        vestings[account].released = 0;
        vestings[account].lastPayment = 0;
        vestings[account].amountSold = 0;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(amount > 0, "Transfer amount must be greater than zero");
        require(vestedBalanceOf(to) == 0, "Recipient has vested tokens");

        if (vestedBalanceOf(from) > 0) {
            release(from);

            require(balanceAvailable(from) >= amount, "ERC20: transfer amount exceeds balance available");
            vestings[from].amountSold += amount;
        }

        if (inVestingPeriod) {
            vestings[to].vestedBalance = vestings[to].vestedBalance.add(amount);
            vestings[to].lastPayment = block.timestamp;

            return;
        }
    }

    event TokensReleased(address indexed account, uint256 amount);

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}
