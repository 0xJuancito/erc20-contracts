// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

abstract contract ERC20VestableInTimestamp is ERC20Burnable, AccessControl {
    bytes32 internal constant GRANTOR_ROLE = keccak256("GRANTOR_ROLE");

    // Date-related constants for sanity-checking dates to reject obvious erroneous inputs
    // and conversions from seconds to days and years that are more or less leap year-aware.
    uint256 private constant SECONDS_PER_DAY = 60 * 60 * 24; /* 86400 seconds in a day */
    uint256 private constant TEN_YEARS_SECONDS = SECONDS_PER_DAY * 365 * 10; /* Seconds in ten years */
    uint256 private constant JAN_1_2000 = 946684800; /* Saturday, January 1, 2000 0:00:00 (GMT) (see https://www.epochconverter.com/) */
    uint256 private constant JAN_1_3000 = 32503680000;

    /**
     * Vesting Schedule
     */
    struct VestingSchedule {
        string scheduleName; // Name of vesting schedule.
        bool isActive; // Status of available.
        uint256 startTimestamp; // Timestamp of vesting schedule beginning.
        uint256 cliffDuration; // A period of time which token be locked.
        uint256 duration; // A period of time which token be released from 0 to max vesting amount.
    }

    /**
     * User's vesting information in a schedule
     */
    struct VestingForAccount {
        string scheduleName;
        uint256 amountVested;
        uint256 amountNotVested;
        uint256 amountOfGrant;
        uint256 vestStartTimestamp;
        uint256 cliffDuration;
        uint256 vestDuration;
        bool isActive;
    }

    // Info of each vesting schedule.
    mapping(uint256 => VestingSchedule) public vestingSchedules;
    // Array of all active schedules, each element is an 'id' value from the vesting schedule rounds
    uint256[] public allActiveSchedules;
    // Vesting amount of user in a schedule.
    mapping(address => mapping(uint256 => uint256)) public userVestingAmountInSchedule;
	// Whether transfers are disabled or not
    bool internal protected = true;
    // Array of all addresses which are allowed to spend within locking period.
    address[] whiteLists;
    // Check an address is whiteList or not.
    mapping(address => bool) public isWhiteList;


    event VestingScheduleUpdated(
        uint256 indexed id,
        string indexed name,
        bool indexed isActive,
        uint256 startTimestamp,
        uint256 cliffDuration,
        uint256 duration
    );

    modifier onlyAdmin() {
        require(isAdmin(_msgSender()), "must have admin role");
        _;
    }

    modifier onlyGrantor() {
        require(isGrantor(_msgSender()), "must have grantor role");
        _;
    }

    modifier onlyGrantorOrSelf(address account) {
        require(
            isGrantor(_msgSender()) || _msgSender() == account,
            "must have grantor role or self"
        );
        _;
    }

    function isAdmin(address account) public view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, account);
    }

    function isGrantor(address account) public view returns (bool) {
        return hasRole(GRANTOR_ROLE, account);
    }

    function getAllActiveSchedules() external view returns (uint256[] memory) {
        return allActiveSchedules;
    }

    function getWhiteLists() external view onlyAdmin returns (address[] memory) {
        return whiteLists;
    }

    /**
     * @dev This operation adds an address to the whiteLists list.
     *
     * @param _whiteListAddress = Address is being whiteList.
     */
    function addWhiteList(
        address _whiteListAddress
    ) internal {
        isWhiteList[_whiteListAddress] = true;
        // If we already have this address in our whiteLists, just bail out
		for (uint256 i = 0; i < whiteLists.length; i++) {
			if (whiteLists[i] == _whiteListAddress)
				return;
		}
		whiteLists.push(_whiteListAddress);
    }

    /**
     * @dev This operation removes an address from the whiteLists list.
     *
     * @param _whiteListAddress = Address is being removed.
     */
    function removeWhiteList(
        address _whiteListAddress
    ) internal {
        isWhiteList[_whiteListAddress] = false;
        for (uint256 i = 0; i < whiteLists.length; i++) {
            if (whiteLists[i] == _whiteListAddress) {
				// We found the element we need to remove
				// first copy the last item over where X is, then delete the last item of the array
				whiteLists[i] = whiteLists[whiteLists.length - 1];
                whiteLists.pop();
                return;
            }
        }
    }

    /**
     * @dev This operation removes a schedule from the active schedule list.
     *
     * @param _id = Vesting schedule ID.
     */
    function removeActiveSchedule(uint256 _id) internal {
        for (uint256 i = 0; i < allActiveSchedules.length; i++) {
            if (allActiveSchedules[i] == _id) {
				// We found the element we need to remove
				// first copy the last item over where X is, then delete the last item of the array
				allActiveSchedules[i] = allActiveSchedules[allActiveSchedules.length - 1];
                allActiveSchedules.pop();
                return;
            }
        }
    }

	/**
     * @dev This operation adds a schedule to the active schedule list.
     *
     * @param _id = Vesting schedule ID.
     */
	function addActiveSchedule(uint256 _id) internal {
		// If we already have this id in our active schedules, just bail out
		for (uint256 i = 0; i < allActiveSchedules.length; i++) {
			if (allActiveSchedules[i] == _id)
				return;
		}
		allActiveSchedules.push(_id);
	}

    // ===========================================================
    // === Grantor's available functions.
    // ===========================================================

    // Set a batch of addresses as whitelists.
    function setWhiteList(
        address[] calldata _whiteListAddresses,
        bool[] calldata _status
    ) external onlyGrantor {
        require(_whiteListAddresses.length > 0, "invalid length");
        require(_whiteListAddresses.length == _status.length, "invalid whiteListAddresses/status length");
        for (uint256 i = 0; i < _whiteListAddresses.length; i++) {
            if (_status[i]) {
                addWhiteList(_whiteListAddresses[i]);
            } else {
                removeWhiteList(_whiteListAddresses[i]);
            }
        }
    }

	function getProtection() public view onlyGrantor returns (bool) {
		return protected;
	}

	function setProtection(bool _protected) public onlyGrantor {
		protected = _protected;
	}

    // Update the vesting schedule definitions
    function updateVestingSchedules(
        string[] calldata _scheduleNames,
        uint256[] calldata _ids,
        bool[] calldata _isActives,
        uint256[] calldata _startTimestamps,
        uint256[] calldata _cliffDurations,
        uint256[] calldata _durations
    ) external onlyGrantor {
        for (uint i = 0; i < _scheduleNames.length; i++) {
            // Check for a valid vesting schedule give (disallow absurd values to reject likely bad input).
            require(_ids[i] != 0 && _ids[i] < 1000, appendUintToString("invalid vesting schedule ", _ids[i]));
            require(
                _durations[i] > 0 &&
                _durations[i] <= TEN_YEARS_SECONDS &&
                _cliffDurations[i] < _durations[i],
                appendUintToString("invalid vesting schedule ", _durations[i])
            );

            require(
                _startTimestamps[i] >= JAN_1_2000 && _startTimestamps[i] < JAN_1_3000,
                appendUintToString("invalid start timestamp", _startTimestamps[i])
            );

            VestingSchedule storage vestingSchedule = vestingSchedules[_ids[i]];
			// update allActiveSchedules
            if (vestingSchedule.isActive && !_isActives[i]) {
				removeActiveSchedule(_ids[i]);
            } else
			if (!vestingSchedule.isActive && _isActives[i]) {
				addActiveSchedule(_ids[i]);
            }
            // update vestingSchedule
            vestingSchedule.scheduleName = _scheduleNames[i];
            vestingSchedule.isActive = _isActives[i];
            vestingSchedule.startTimestamp = _startTimestamps[i];
            vestingSchedule.cliffDuration = _cliffDurations[i];
            vestingSchedule.duration = _durations[i];

            emit VestingScheduleUpdated(
                _ids[i],
                _scheduleNames[i],
                _isActives[i],
                _startTimestamps[i],
                _cliffDurations[i],
                _durations[i]
            );
        }
    }

	function appendUintToString(string memory inStr, uint256 _i) internal pure returns (string memory str) {
		if (_i == 0)
		{
			return "0";
		}
		uint256 j = _i;
		uint256 length = 0;
		while (j != 0)
		{
			length++;
			j /= 10;
		}
		
		bytes memory inbstr= bytes(inStr);		
		uint256 k = inbstr.length + length;
		bytes memory bstr = new bytes(k);
		// copy the string over
		j = 0;
		while (j < inbstr.length) {
			bstr[j] = inbstr[j];
			j++;
		}
        // now copy the stringified uint over
		j = _i;
		while (j != 0)
		{
			bstr[--k] = bytes1(uint8(48 + j % 10));
			j /= 10;
		}
		str = string(bstr);
    }
	
    /**
     * @dev Immediately set multi vesting schedule to an address, the token in their wallet will vest over time
     * according to this schedule.
     *
     * @param _beneficiaries = Addresses to which tokens will be vested.
     * @param _vestingScheduleIDs = Vesting schedule IDs.
     * @param _vestingAmounts = The amount of tokens that will be vested.
     */
    function applyMultiVestingSchedule(
        address[] calldata _beneficiaries,
        uint256[] calldata _vestingScheduleIDs,
        uint256[] calldata _vestingAmounts
    ) external onlyGrantor returns (bool ok) {
        require(_beneficiaries.length == _vestingScheduleIDs.length, "invalid schedules length");
        require(_vestingScheduleIDs.length == _vestingAmounts.length, "invalid amounts length");

        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            require(_vestingScheduleIDs[i] != 0, "invalid vesting schedule");
			require(_vestingAmounts[i] != 0, "invalid vesting amount");
            require(
                userVestingAmountInSchedule[_beneficiaries[i]][_vestingScheduleIDs[i]] == 0,
                appendUintToString("already applied vesting schedule ", i)
            );
            require(
                vestingSchedules[_vestingScheduleIDs[i]].isActive,
                appendUintToString("vesting schedule is not active ", i)
            );

			// Actually set up the vesting schedule for the beneficiary
			userVestingAmountInSchedule[_beneficiaries[i]][_vestingScheduleIDs[i]] = _vestingAmounts[i];
        }

        return true;
    }

    function transferVestingTokens(
        address[] calldata _beneficiaries,
        uint256[] calldata _vestingScheduleIDs
    ) external onlyAdmin {
        require(_beneficiaries.length == _vestingScheduleIDs.length, "invalid schedules length");
        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            require(
                userVestingAmountInSchedule[_beneficiaries[i]][_vestingScheduleIDs[i]] > 0,
                appendUintToString("beneficiary has no tokens to transfer in this schedule ", i)
            );

            super.transfer(_beneficiaries[i], userVestingAmountInSchedule[_beneficiaries[i]][_vestingScheduleIDs[i]]);
        }
    }

    // ============================================================
    // === Check vesting information.
    // ============================================================

    // Get the timestamp of the current day, in seconds since the UNIX epoch.
    function today() public view returns (uint256) {
        return block.timestamp;
    }

    function _effectiveDay(uint256 onDayOrToday)
        internal
        view
        returns (uint256)
    {
        return onDayOrToday == 0 ? today() : onDayOrToday;
    }

    // Get all of schedules user is having
    function getAllSchedulesOfBeneficiary(address _beneficiary)
        public
        view
        returns (uint256[] memory userActiveSchedules)
    {
        uint256 activeCount = 0;
		// Get the schedules which are active and the beneficiary also has tokens vesting in
        uint256[] memory schedules = new uint256[](allActiveSchedules.length);
        for (uint256 i = 0; i < allActiveSchedules.length; i++) {
            if (userVestingAmountInSchedule[_beneficiary][allActiveSchedules[i]] > 0) {
                schedules[activeCount] = allActiveSchedules[i];
                activeCount++;
            }
        }

        userActiveSchedules = new uint256[](activeCount);
        for (uint256 i = 0; i < activeCount; i++) {
            userActiveSchedules[i] = schedules[i];
        }
    }

    /**
     * @dev Determines the amount of token that have not vested for 1 schedule in the give address.
     *
     * notVestAmount = vestingAmount * (endDate - onDate)/(endDate - startDate)
     *
     * @param _beneficiary = The address to check
     * @param _onDayOrToday = The day to check, in seconds since the UNIX epoch.
     * Pass `0` if indicate TODAY.
     */
    function _getNotVestedAmount(
        address _beneficiary,
        uint256 _vestingSchedule,
        uint256 _onDayOrToday
    ) internal view returns (uint256) {
        uint256 userVestingAmount = userVestingAmountInSchedule[_beneficiary][_vestingSchedule];
        if (userVestingAmount == 0) return uint256(0);
        VestingSchedule storage vesting = vestingSchedules[_vestingSchedule];
        uint256 onDay = _effectiveDay(_onDayOrToday);

        // If there's no schedule, or before the vesting cliff, then the full amount is not vested.
        if (
            !vesting.isActive ||
            onDay < vesting.startTimestamp + vesting.cliffDuration
        ) {
            // None are vested (all are not vested)
            return userVestingAmount;
        }
        // If after end of cliff + vesting, then the not vested amount is zero (all are vested).
        else if (
            onDay >=
            vesting.startTimestamp + (vesting.cliffDuration + vesting.duration)
        ) {
            // All are vested (none are not vested)
            return uint256(0);
        }
        // Otherwise a fractional amount is vested.
        else {
            // Compute the exact number of days vested.
            uint256 daysVested = onDay - (vesting.startTimestamp + vesting.cliffDuration);

            // Compute the fraction vested from schedule using 224.32 fixed point math for date range ratio.
            // Note: This is safe in 256-bit math because max value of X billion tokens = X*10^27 wei, and
            // typical token amounts can fit into 90 bits. Scaling using a 32 bits value results in only 125
            // bits before reducing back to 90 bits by dividing. There is plenty of room left, even for token
            // amounts many orders of magnitude greater than mere billions.
            uint256 vested = (userVestingAmount * daysVested) / vesting.duration;
            return userVestingAmount - vested;
        }
    }

    /**
     * @dev Determines the all amount of token that have not vested in multiple schedules in the give account.
     *
     * notVestAmount = vestingAmount * (endDate - onDate)/(endDate - startDate)
     *
     * @param _beneficiary = The account to check
     * @param _onDayOrToday = The day to check, in seconds since the UNIX epoch.
     * Pass `0` if indicate TODAY.
     */
    function _getNotVestedAmountForAllSchedules(
        address _beneficiary,
        uint256 _onDayOrToday
    ) internal view returns (uint256 notVestedAmount) {
        uint256[] memory userSchedules = getAllSchedulesOfBeneficiary(_beneficiary);
        if (userSchedules.length == 0) return uint256(0);

        for (uint256 i = 0; i < userSchedules.length; i++) {
            notVestedAmount += _getNotVestedAmount(
                _beneficiary,
                userSchedules[i],
                _onDayOrToday
            );
        }
    }

    /**
     * @dev Computes the amount of funds in the given account which are available for use as of
     * the given day. If there's no vesting schedule then 0 tokens are considered to be vested and
     * this just returns the full account balance.
     *
     * availableAmount = totalFunds - notVestedAmount.
     *
     * @param _beneficiary = The account to check.
     * @param _onDay = The day to check for, in seconds since the UNIX epoch.
     */
    function _getAvailableAmount(address _beneficiary, uint256 _onDay)
        internal
        view
        returns (uint256)
    {
        uint256 totalTokens = balanceOf(_beneficiary);
        uint256 vested = totalTokens - _getNotVestedAmountForAllSchedules(_beneficiary, _onDay);
        return vested;
    }

    function vestingForBeneficiaryAsOf(address _beneficiary, uint256 _onDayOrToday)
        public
        view
        onlyGrantorOrSelf(_beneficiary)
        returns (VestingForAccount[] memory userVestingInfo)
    {
        uint256[] memory userSchedules = getAllSchedulesOfBeneficiary(_beneficiary);
        if (userSchedules.length == 0) {
            return userVestingInfo;
        }

        userVestingInfo = new VestingForAccount[](userSchedules.length);
        for (uint256 i = 0; i < userSchedules.length; i++) {
            uint256 userVestingAmount = userVestingAmountInSchedule[_beneficiary][userSchedules[i]];
            VestingSchedule storage vesting = vestingSchedules[userSchedules[i]];
            uint256 notVestedAmount = _getNotVestedAmount(
                _beneficiary,
                userSchedules[i],
                _onDayOrToday
            );

            userVestingInfo[i] = VestingForAccount({
                scheduleName: vesting.scheduleName,
                amountVested: userVestingAmount - notVestedAmount,
                amountNotVested: notVestedAmount,
                amountOfGrant: userVestingAmount,
                vestStartTimestamp: vesting.startTimestamp,
                cliffDuration: vesting.cliffDuration,
                vestDuration: vesting.duration,
                isActive: vesting.isActive
            });
        }
    }

    /**
     * @dev returns all information about the grant's vesting as of the given day
     * for the current account, to be called by the account holder.
     *
     * @param onDayOrToday = The day to check for, in seconds since the UNIX epoch. Can pass
     *   the special value 0 to indicate today.
     */
    function vestingAsOf(uint256 onDayOrToday)
        public
        view
        returns (VestingForAccount[] memory userVestingInfo)
    {
        return vestingForBeneficiaryAsOf(_msgSender(), onDayOrToday);
    }

    /**
     * @dev returns true if the account has sufficient funds available to cover the given amount,
     *   including consideration for vesting tokens.
     *
     * @param _account = The account to check.
     * @param _amount = The required amount of vested funds.
     * @param _onDay = The day to check for, in seconds since the UNIX epoch.
     */
    function _fundsAreAvailableOn(
        address _account,
        uint256 _amount,
        uint256 _onDay
    ) internal view returns (bool) {
        return (_amount <= _getAvailableAmount(_account, _onDay));
    }

    /**
     * @dev Modifier to make a function callable only when the amount is sufficiently vested right now.
     *
     * @param account = The account to check.
     * @param amount = The required amount of vested funds.
     */
    modifier onlyIfFundsAvailableNow(address account, uint256 amount) {
        // Distinguish insufficient overall balance from insufficient vested funds balance in failure msg.
        require(
            _fundsAreAvailableOn(account, amount, today()),
            balanceOf(account) < amount
                ? "insufficient funds"
                : "insufficient vested funds"
        );
        _;
    }

    // =========================================================================
    // === Overridden ERC20 functionality
    // =========================================================================

    /**
     * @dev Methods burn(), burnFrom(), mint(), transfer() and transferFrom() require an additional available funds check to
     * prevent spending held but non-vested tokens.
     */

    function burn(uint256 value)
        public
        override
        onlyIfFundsAvailableNow(_msgSender(), value)
    {
        super.burn(value);
    }

    function burnFrom(address account, uint256 value)
        public
        override
        onlyIfFundsAvailableNow(account, value)
    {
        super.burnFrom(account, value);
    }

    function transfer(address to, uint256 value)
        public
        override
        onlyIfFundsAvailableNow(_msgSender(), value)
        returns (bool)
    {
        if (protected) {
            require(
                isWhiteList[_msgSender()],
                "sender is not allowed to transfer while token is locked"
            );
        }

        return super.transfer(to, value);
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public override onlyIfFundsAvailableNow(from, value) returns (bool) {
        if (protected) {
            require(
                isWhiteList[from],
                "sender is not allowed to transfer while token is locked"
            );
        }

        return super.transferFrom(from, to, value);
    }
}
