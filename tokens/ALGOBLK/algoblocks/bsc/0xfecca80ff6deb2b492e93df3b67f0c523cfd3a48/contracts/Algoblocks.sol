// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Algoblocks is ERC20 {

    enum Role {
        NONE,
        TEAM,
        ADVISORS,
        PARTNERSHIPS,
        IDO_INVESTORS,
        PRIVATE_INVESTORS,
        STRATEGIC_INVESTORS,
        GRANTS,
        MARKETING,
        MARKET_MAKERS,
        ECOSYSTEM_DEV
    }  // Available roles in the contract

    struct Holdup {
        uint paymentDate;       // When payment has been made
        uint256 amount;         // Amount transfered
    }

    struct VestingPlan {
        uint cliff;             // Number of days until linear release of funds
        uint vestingMonths;     // Number of months (month = 30.5 days) of vesting release
        uint256 dayOneRelease;  // Percentage (in 0.01 units) released on day one - excluded from vesting
    }

    event TokenGeneration(uint256 amount);
    event TransferWithVesting(address to, uint256 amount, uint role);
    event ReturnFrom(address account, uint256 amount);

    uint private _fullReleaseTimestamp; // Timestamp when all funds are released and no more checks on transfer is needed
   
    /*
    * @dev Total token supply. ALGOBLKs are fixed token supply
    */
    uint256 public constant TOTAL_SUPPLY = 186_966_000;

    /*
    * @dev airdrop token supply. Fixed supply to be minted and distributed to owner before the rest at TGE
    */
    uint256 public constant AIRDROP_SUPPLY = 1_034_000;

    /**
    * Marks Token generation event
    */
    bool private _executed = false;

    mapping(Role => mapping(address => Holdup)) private _lockedRecipients;
    mapping(address => Role) private _lockedMap;
    mapping(Role => VestingPlan) private _vestingPlan;

    address private _owner;

    modifier onlyOwner() {
        require(_owner == _msgSender(), "caller is not the owner");
        _;
    }
    modifier executedOnlyOnce(){
        require(!_executed, "Tokens have already been generated");
        _;
    }

    constructor(address ownerWallet)
    ERC20("Algoblocks", "ALGOBLK")
    {
        // Configure Vesting system here
        _configurePlan(Role.TEAM, 8 * (30.5 days), 24, 0);
        _configurePlan(Role.ADVISORS, 8 * (30.5 days), 24, 0);
        _configurePlan(Role.PRIVATE_INVESTORS, (30.5 days), 15, 750);
        _configurePlan(Role.STRATEGIC_INVESTORS, 2 * (30.5 days), 18, 250);
        _configurePlan(Role.IDO_INVESTORS, 0, 3, 2500);
        _configurePlan(Role.MARKETING, (7 days), 12, 0);
        _configurePlan(Role.PARTNERSHIPS, (7 days), 24, 0);
        _configurePlan(Role.GRANTS, (30.5 days), 12, 0);
        _configurePlan(Role.MARKET_MAKERS, (7 days), 12, 0);
        _configurePlan(Role.ECOSYSTEM_DEV, (30.5 days), 12, 0);
        _owner = ownerWallet;
        _mint(_owner, AIRDROP_SUPPLY * (10 ** decimals()));
    }

    function generateTokens(
        address[] memory teamAddresses,
        uint256[] memory teamAmounts,
        address[] memory advisorsAddresses,
        uint256[] memory advisorsAmounts,
        address[] memory privateInvestorsAddresses,
        uint256[] memory privateInvestorsAmounts,
        address[] memory strategicInvestorsAddresses,
        uint256[] memory strategicInvestorsAmounts,
        address[] memory idoInvestorsAddresses,
        uint256[] memory idoInvestorsAmounts
    )
    external
    onlyOwner
    executedOnlyOnce 
    returns (uint256 team, uint256 mintedToOwner) {
        _fullReleaseTimestamp = block.timestamp + (30.5 days) * 32;
        uint256 supply = TOTAL_SUPPLY * (10 ** decimals());
        // Full release after 30 months - team and advisors
        uint256 distributedTeamAmount = _distribute(Role.TEAM, teamAddresses, teamAmounts);
        supply -= distributedTeamAmount;
        supply -= _distribute(Role.ADVISORS, advisorsAddresses, advisorsAmounts);
        supply -= _distribute(Role.PRIVATE_INVESTORS, privateInvestorsAddresses, privateInvestorsAmounts);
        supply -= _distribute(Role.STRATEGIC_INVESTORS, strategicInvestorsAddresses, strategicInvestorsAmounts);
        supply -= _distribute(Role.IDO_INVESTORS, idoInvestorsAddresses, idoInvestorsAmounts);
        _mint(_owner, supply);
        _executed = true;
        emit TokenGeneration(TOTAL_SUPPLY * (10 ** decimals()) - supply);
        return (
            distributedTeamAmount,
            supply
        );
    }

    function burn(uint256 amount) external {
        _burn(_msgSender(), amount);
    }

    function transferWithVesting(address to, uint256 amount, uint role) external onlyOwner {
        require(_lockedMap[to] == Role.NONE, "Recipient already received vested money");

        _transfer(_msgSender(), to, amount);

        Role r = _toRole(role);
        _lockedMap[to] = r;
        _lockedRecipients[r][to].amount = amount;
        _lockedRecipients[r][to].paymentDate = block.timestamp;

        uint256 finalReleaseDate = _fullReleaseDateForRole(r, to);
        if (finalReleaseDate > _fullReleaseTimestamp) {
            _fullReleaseTimestamp = finalReleaseDate;
        }
        emit TransferWithVesting(to, amount, role);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {

        // If we haven't reached a global deadline, we need to make additional checks
        if (to != _owner && block.timestamp < _fullReleaseTimestamp) {

            // First, if sender is in the group of locked recipients
            if (_lockedMap[from] != Role.NONE) {

                // Now we know how much money owner has available
                uint256 availableFunds = balanceOf(from) - _amountLocked(from);

                // Time to check if the transfer does not exceed the amount available
                require(amount <= availableFunds, "Tokens are locked accordingly to your vesting plan.");
            }
        }

        super._beforeTokenTransfer(from, to, amount);
    }

    function _toRole(uint roleId) private pure returns (Role) {
        require(roleId >= 0, "Role Id too small");
        require(roleId <= 10, "Role Id too big");

        if (roleId == 1) {
            return Role.TEAM;
        } else if (roleId == 2) {
            return Role.ADVISORS;
        } else if (roleId == 3) {
            return Role.PARTNERSHIPS;
        } else if (roleId == 4) {
            return Role.IDO_INVESTORS;
        } else if (roleId == 5) {
            return Role.PRIVATE_INVESTORS;
        } else if (roleId == 6) {
            return Role.STRATEGIC_INVESTORS;
        } else if (roleId == 7) {
            return Role.GRANTS;
        } else if (roleId == 8) {
            return Role.MARKETING;
        } else if (roleId == 9) {
            return Role.MARKET_MAKERS;
        } else if (roleId == 10) {
            return Role.ECOSYSTEM_DEV;
        }
        return Role.NONE;
    }

    function _configurePlan(Role role, uint cliff, uint vestingMonths, uint dayOneRelease) private {
        _vestingPlan[role].cliff = cliff;
        _vestingPlan[role].vestingMonths = vestingMonths;
        _vestingPlan[role].dayOneRelease = dayOneRelease;
    }

    function lockedBalanceOf(address account) external view returns (uint256) {
        return _amountLocked(account);
    }

    function returnFrom(address account) external onlyOwner returns (uint256) {
        Role role = _lockedMap[account];

        require(role == Role.TEAM, 'account is not a team holder');

        uint256 lockedAmount = _amountLocked(account);

        if (lockedAmount > 0) {
            _transfer(account, _owner, lockedAmount);
            _lockedRecipients[role][account].paymentDate = 0;
            _lockedRecipients[role][account].amount = 0;
            _lockedMap[account] = Role.NONE;
        }
        emit ReturnFrom(account, lockedAmount);
        return lockedAmount;
    }

    function _amountLocked(address account) private view returns (uint256) {

        Role role = _lockedMap[account];

        if (role == Role.NONE) {
            return 0;
        }

        // Checking how much was initially transfered and locked
        uint256 amountLocked = _lockedRecipients[role][account].amount;

        // First, substract tokens released on TGE
        amountLocked -= (_vestingPlan[role].dayOneRelease * amountLocked) / 10000;

        // Only if cliff timestamp has been reached we can calculate further
        uint256 cliff = _lockedRecipients[role][account].paymentDate + _vestingPlan[role].cliff;
        if (block.timestamp > cliff) {
            // To check how much money one can use we need to divide time passed since the cliff by number of months
            
            uint256 monthsPassed = (block.timestamp - cliff) / (30.5 days);
            if (monthsPassed < _vestingPlan[role].vestingMonths) {
                amountLocked -= (amountLocked / _vestingPlan[role].vestingMonths) * monthsPassed;
            } else {
                amountLocked = 0;
            }
        }

        return amountLocked;
    }


    function _distribute(Role role,
        address[] memory addresses,
        uint256[] memory amounts) private returns (uint256) {
        require(addresses.length == amounts.length, "Wrong number of members");
        uint256 used = 0;
        for (uint i = 0; i < addresses.length; i++) {
            uint256 amount = amounts[i] * (10 ** decimals());
            _mint(addresses[i], amount);
            used += amount;
            _lockedRecipients[role][addresses[i]].paymentDate = block.timestamp;
            _lockedRecipients[role][addresses[i]].amount = amount;
            _lockedMap[addresses[i]] = role;
        }

        return used;
    }

    function _fullReleaseDateForRole(Role role, address account) private view returns (uint) {
        return _lockedRecipients[role][account].paymentDate + _vestingPlan[role].cliff + _vestingPlan[role].vestingMonths * (30.5 days);
    }
}