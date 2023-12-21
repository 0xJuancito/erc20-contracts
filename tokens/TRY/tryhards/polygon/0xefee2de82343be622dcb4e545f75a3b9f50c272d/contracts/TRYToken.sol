pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

struct VestingWallet {
    address wallet;
    uint256 totalAmount;
    uint256 dayAmount;
    uint256 startDay;
    uint256 afterDays;
    uint256 firstMonthAmount;
    uint256 initialDelay;
}

/**
 * dailyRate:               the daily amount of tokens to give access to,
 *                          this is a percentage * 1000000000000000000
 * afterDays:               vesting cliff, dont allow any withdrawal before these days expired
 * firstMonthDailyUnlock:   same as dailyRate but for the first 30 days, which are unlocked all at the same time
**/

struct VestingType {
    uint256 dailyRate;
    uint256 afterDays;
    uint256 firstMonthDailyUnlock;
    uint256 initialDelay;
}

import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract TRYToken is Ownable, ERC20Burnable {
    
    using SafeMath for uint256;
    
    mapping (address => VestingWallet[]) public vestingWallets;
    VestingType[] public vestingTypes;

    uint256 public constant PRECISION = 1e18;
    uint256 public constant ONE_HUNDRED_PERCENT = PRECISION * 100;
        
    /**
     * Setup the initial supply and types of vesting schemas
    **/
    
    constructor() ERC20("TryHards", "TRY") {
        
        // 0 (seed): 360 days, 5.00% first month, 6 hours delayed
        vestingTypes.push(VestingType(287878787878787879, 0 days, 166666666666666667, 21600));

        // 1 (strategic): 360 days, 10.0% first month, 4 hours delayed
        vestingTypes.push(VestingType(272727272727272727, 0 days, 333333333333333333, 14400));

        // 2 (private): 270 days, 10.0% first month, 2 hours delayed
        vestingTypes.push(VestingType(375000000000000000, 0 days, 333333333333333333, 7200));

        // 3 (team): 720 days, default% first month, 0 hours delayed
        vestingTypes.push(VestingType(138888888888888896, 360 days, 138888888888888896, 0));

        // 4 (airdrop): 0 days, default% first month, 0 hours delayed
        vestingTypes.push(VestingType(100000000000000000000, 30 days, 100000000000000000000, 0));

        // 5 (advisors): 540 days, default% first month, 0 hours delayed
        vestingTypes.push(VestingType(185185185185185184, 90 days, 185185185185185184, 0));

        // 6 (play2earn): 1440 days, 10.0% first month, 0 hours delayed
        vestingTypes.push(VestingType(63829787234042553, 30 days, 333333333333333333, 0));

        // 7 (staking): 1080 days, 10.0% first month, 0 hours delayed
        vestingTypes.push(VestingType(85714285714285714, 30 days, 333333333333333333, 0));

        // 8 (treasury): 720 days, default% first month, 0 hours delayed
        vestingTypes.push(VestingType(138888888888888896, 90 days, 138888888888888896, 0));

        // 9 (development): 720 days, default% first month, 0 hours delayed
        vestingTypes.push(VestingType(138888888888888896, 360 days, 138888888888888896, 0));

        
        // Release before token start, IDO
        _mint(address(0x81E218CAA01065fc094e20f4515b3e03b5f8460D), 10000000e18);
        
        // Release before token start, Liquidity 
        _mint(address(0xBdB8F09191BaEc8C03E1be40c9E63094ECEaB823), 3000000e18);
        
        // Release before token start, Advisor #2
        _mint(address(0xcB1dcEc4A437460cB68BAE8e0Be5A0842C27D722), 3000000e18);
        
    }
	
    // Vested tokens wont be available before the listing time
    function getListingTime() public pure returns (uint256) {
        return 1637769600; // 2021/11/24 16:00 UTC
        //return 1640995200; // 2022/01/01 midnight, used for test runs
    }

    function getMaxTotalSupply() public pure returns (uint256) {
        return PRECISION * 200000000; // 200 million tokens with 18 decimals
    }

    function mulDiv(uint256 x, uint256 y, uint256 z) private pure returns (uint256) {
        return x.mul(y).div(z);
    }
    
    function addAllocations(address[] memory addresses, uint256[] memory totalAmounts, uint256 vestingTypeIndex) external onlyOwner returns (bool) {
        require(addresses.length == totalAmounts.length, "Address and totalAmounts length must be same");
        require(vestingTypeIndex < vestingTypes.length, "Vesting type isnt found");

        VestingType memory vestingType = vestingTypes[vestingTypeIndex];
        uint256 addressesLength = addresses.length;

        for(uint256 i = 0; i < addressesLength; i++) {
            address _address = addresses[i];
            uint256 totalAmount = totalAmounts[i];
            // We add 1 to round up, this prevents small amounts from never vesting
            uint256 dayAmount = mulDiv(totalAmounts[i], vestingType.dailyRate, ONE_HUNDRED_PERCENT);
            uint256 afterDay = vestingType.afterDays;
            uint256 initialDelay = vestingType.initialDelay;
            uint256 firstMonthAmount = mulDiv(totalAmounts[i], vestingType.firstMonthDailyUnlock, ONE_HUNDRED_PERCENT).mul(30);

            addVestingWallet(_address, totalAmount, dayAmount, afterDay, firstMonthAmount, initialDelay);
        }

        return true;
    }

    function _mint(address account, uint256 amount) internal override {
        uint256 totalSupply = super.totalSupply();
        require(getMaxTotalSupply() >= totalSupply.add(amount), "Maximum supply exceeded!");
        super._mint(account, amount);
    }

    function addVestingWallet(address wallet, uint256 totalAmount, uint256 dayAmount, uint256 afterDays, uint256 firstMonthAmount, uint256 initialDelay) internal {

        uint256 releaseTime = getListingTime();

        // Create vesting wallets
        VestingWallet memory vestingWallet = VestingWallet(
            wallet,
            totalAmount,
            dayAmount,
            releaseTime.add(afterDays),
            afterDays,
            firstMonthAmount,
            initialDelay
        );
            
        vestingWallets[wallet].push(vestingWallet);
        _mint(wallet, totalAmount);
    }

    function getTimestamp() external view returns (uint256) {
        return block.timestamp;
    }

    /**
     * Returns the amount of days passed with vesting
     */

    function getDays(uint256 afterDays, uint256 initialDelay) public view returns (uint256) {
        uint256 releaseTime = getListingTime().add(initialDelay);
        uint256 time = releaseTime.add(afterDays);

        if (block.timestamp < time) {
            return 0;
        }

        uint256 diff = block.timestamp.sub(time);
        uint256 ds = diff.div(1 days).add(1);
        
        return ds;
    }

    function isStarted(uint256 startDay) public view returns (bool) {
        uint256 releaseTime = getListingTime();

        if (block.timestamp < releaseTime || block.timestamp < startDay) {
            return false;
        }

        return true;
    }
    
    // Returns the amount of tokens unlocked by vesting so far
    function getUnlockedVestingAmount(address sender) public view returns (uint256) {
        
        if (!isStarted(0)) {
            return 0;
        }
        
        uint256 dailyTransferableAmount = 0;

        for (uint256 i=0; i<vestingWallets[sender].length; i++) {

            if (vestingWallets[sender][i].totalAmount == 0) {
                continue;
            }

            uint256 trueDays = getDays(vestingWallets[sender][i].afterDays, vestingWallets[sender][i].initialDelay);
            uint256 dailyTransferableAmountCurrent = 0;
            
            // Unlock the first month right away on the first day of vesting;
            // But only start the real vesting after the first month (0, 30, 30, .., 31)
            if (trueDays > 0 && trueDays < 30) {
                trueDays = 30; 
                dailyTransferableAmountCurrent = vestingWallets[sender][i].firstMonthAmount;
            } 

            if (trueDays >= 30) {
                dailyTransferableAmountCurrent = vestingWallets[sender][i].firstMonthAmount.add(vestingWallets[sender][i].dayAmount.mul(trueDays.sub(30)));
            }

            if (dailyTransferableAmountCurrent > vestingWallets[sender][i].totalAmount) {
                dailyTransferableAmountCurrent = vestingWallets[sender][i].totalAmount;
            }

            dailyTransferableAmount = dailyTransferableAmount.add(dailyTransferableAmountCurrent);
        }

        return dailyTransferableAmount;
    }
    
    function getTotalVestedAmount(address sender) public view returns (uint256) {
        uint256 totalAmount = 0;

        for (uint256 i=0; i<vestingWallets[sender].length; i++) {
            totalAmount = totalAmount.add(vestingWallets[sender][i].totalAmount);
        }
        return totalAmount;
    }

    // Returns the amount of vesting tokens still locked
    function getRestAmount(address sender) public view returns (uint256) {
        uint256 transferableAmount = getUnlockedVestingAmount(sender);
        uint256 totalAmount = getTotalVestedAmount(sender);
        uint256 restAmount = totalAmount.sub(transferableAmount);
        return restAmount;
    }

    // Transfer control 
    function canTransfer(address sender, uint256 amount) public view returns (bool) {

        // Treat as a normal coin if this is not a vested wallet
        if (vestingWallets[sender].length == 0) {
            return true;
        }

        uint256 balance = balanceOf(sender);
        uint256 restAmount = getRestAmount(sender);
        uint256 totalAmount = getTotalVestedAmount(sender);
        
        // Account for sending received tokens outside of the vesting schedule
        if (balance > totalAmount && balance.sub(totalAmount) >= amount) {
            return true;
        }

        // Don't allow vesting if you are below allowance
        if (balance.sub(amount) < restAmount) {
            return false;
        }

        return true;
    }
    
    // @override
    function _beforeTokenTransfer(address sender, address recipient, uint256 amount) internal virtual override(ERC20) {
        // Reject any transfers that are not allowed
        require(canTransfer(sender, amount), "Unable to transfer, not unlocked yet.");
        super._beforeTokenTransfer(sender, recipient, amount);
    }
}
