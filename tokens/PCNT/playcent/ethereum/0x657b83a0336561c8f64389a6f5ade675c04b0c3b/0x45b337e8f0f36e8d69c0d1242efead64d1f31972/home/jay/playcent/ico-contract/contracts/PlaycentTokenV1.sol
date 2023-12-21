pragma solidity 0.6.2;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "./safety/ILocker.sol";

contract PlaycentTokenV1 is
  Initializable,
  OwnableUpgradeable,
  ERC20PausableUpgradeable,
  ILockerUser
{
  using SafeMathUpgradeable for uint256;
  /**
   * Category 0 - Team
   * Category 1 - Operations
   * Category 2 - Marketing/Partners
   * Category 3 - Advisors
   * Category 4 - Staking/Earn Incentives
   * Category 5 - Play/Mining
   * Category 6 - Reserve
   * Category 7 - Seed Sale
   * Category 8 - Private 1
   * Category 9 - Private 2
   */

  string public releaseSHA;

  struct VestType {
    uint8 indexId;
    uint8 lockPeriod;
    uint8 vestingDuration;
    uint8 tgePercent;
    uint8 monthlyPercent;
    uint256 totalTokenAllocation;
  }

  struct VestAllocation {
    uint8 vestIndexID;
    uint256 totalTokensAllocated;
    uint256 totalTGETokens;
    uint256 monthlyTokens;
    uint8 vestingDuration;
    uint8 lockPeriod;
    uint256 totalVestTokensClaimed;
    bool isVesting;
    bool isTgeTokensClaimed;
  }

  mapping(uint256 => VestType) internal vestTypes;
  mapping(address => mapping(uint8 => VestAllocation))
    public walletToVestAllocations;

  ILocker public override locker;

  function initialize(address _PublicSaleAddress, address _exchangeLiquidityAddress, string memory _hash)
    public
    initializer
  {
    __Ownable_init();
    __ERC20_init("Playcent", "PCNT");
    __ERC20Pausable_init();
    _mint(owner(), 55200000 ether);
    _mint(_PublicSaleAddress, 2400000 ether);
    _mint(_exchangeLiquidityAddress, 2400000 ether);

    releaseSHA = _hash;

    vestTypes[0] = VestType(0, 12, 32, 0, 5, 9000000 ether); // Team
    vestTypes[1] = VestType(1, 3, 13, 0, 10, 4800000 ether); // Operations
    vestTypes[2] = VestType(2, 3, 13, 0, 10, 4800000 ether); // Marketing/Partners
    vestTypes[3] = VestType(3, 1, 11, 0, 10, 2400000 ether); // Advisors
    vestTypes[4] = VestType(4, 1, 6, 0, 20, 4800000 ether); //Staking/Early Incentive Rewards
    vestTypes[5] = VestType(5, 3, 28, 0, 4, 9000000 ether); //Play Mining
    vestTypes[6] = VestType(6, 6, 31, 0, 4, 4200000 ether); //Reserve
    // Sale Vesting Strategies
    vestTypes[7] = VestType(7, 1, 7, 10, 15, 5700000 ether); // Seed Sale
    vestTypes[8] = VestType(8, 1, 5, 15, 20, 5400000 ether); // Private Sale 1
    vestTypes[9] = VestType(9, 1, 4, 20, 20, 5100000 ether); // Private Sale 2
  }

  modifier onlyValidVestingBenifciary(
    address _userAddresses,
    uint8 _vestingIndex
  ) {
    require(_userAddresses != address(0), "Invalid Address");
    require(
      !walletToVestAllocations[_userAddresses][_vestingIndex].isVesting,
      "User Vesting Details Already Added to this Category"
    );
    _;
  }

  modifier checkVestingStatus(address _userAddresses, uint8 _vestingIndex) {
    require(
      walletToVestAllocations[_userAddresses][_vestingIndex].isVesting,
      "User NOT added to the provided vesting Index"
    );
    _;
  }

  modifier onlyValidVestingIndex(uint8 _vestingIndex) {
    require(_vestingIndex >= 0 && _vestingIndex <= 9, "Invalid Vesting Index");
    _;
  }

  modifier onlyAfterTGE() {
    require(
      getCurrentTime() > getTGETime(),
      "Token Generation Event Not Started Yet"
    );
    _;
  }

  function setLocker(address _locker) external onlyOwner() {
    locker = ILocker(_locker);
  }

  // function _transfer(address sender, address recipient, uint256 amount) internal virtual override {
  //     if (address(locker) != address(0)) {
  //         locker.lockOrGetPenalty(sender, recipient);
  //     }
  //     return ERC20._transfer(sender, recipient, amount);
  // }

  function _transfer(
    address sender,
    address recipient,
    uint256 amount
  ) internal virtual override {
    if (address(locker) != address(0)) {
      locker.lockOrGetPenalty(sender, recipient);
    }
    return super._transfer(sender, recipient, amount);
  }

  /**
   * @notice Returns current time
   */
  function getCurrentTime() internal view returns (uint256) {
    return block.timestamp;
  }

  /**
   * @notice Returns the total number of seconds in 1 Day
   */
  function daysInSeconds() internal pure returns (uint256) {
    return 86400;
  }

  /**
   * @notice Returns the total number of seconds in 1 month
   */
  function monthInSeconds() internal pure returns (uint256) {
    return 2592000;
  }

  /**
   * @notice Returns the TGE time
   */
  function getTGETime() public pure returns (uint256) {
    return 1615055400; // March 6, 2021 @ 6:30:00 pm
  }

  /**
   * @notice Calculates the amount of tokens on the basis of monthly rate assigned
   */
  function percentage(uint256 _totalAmount, uint256 _rate)
    internal
    pure
    returns (uint256)
  {
    return _totalAmount.mul(_rate).div(100);
  }

  /**
   * @notice Pauses the contract.
   * @dev Can only be called by the owner
   */
  function pauseContract() external onlyOwner {
    _pause();
  }

  /**
   * @notice Pauses the contract.
   * @dev Can only be called by the owner
   */
  function unPauseContract() external onlyOwner {
    _unpause();
  }

  /**
    * @notice - Allows only the Owner to ADD an array of Addresses as well as their Vesting Amount
              - The array of user and amounts should be passed along with the vestingCategory Index. 
              - Thus, a particular batch of addresses shall be added under only one Vesting Category Index 
    * @param _userAddresses array of addresses of the Users
    * @param _vestingAmounts array of amounts to be vested
    * @param _vestingType allows the owner to select the type of vesting category
    * @return - true if Function executes successfully
    */

  function addVestingDetails(
    address[] calldata _userAddresses,
    uint256[] calldata _vestingAmounts,
    uint8 _vestingType
  ) external onlyOwner onlyValidVestingIndex(_vestingType) returns (bool) {
    require(
      _userAddresses.length == _vestingAmounts.length,
      "Unequal arrays passed"
    );

    // Get Vesting Category Details
    VestType memory vestData = vestTypes[_vestingType];
    uint256 arrayLength = _userAddresses.length;

    uint256 providedVestAmount;

    for (uint256 i = 0; i < arrayLength; i++) {
      uint8 vestIndexID = _vestingType;
      address userAddress = _userAddresses[i];
      uint256 totalAllocation = _vestingAmounts[i];
      uint8 lockPeriod = vestData.lockPeriod;
      uint8 vestingDuration = vestData.vestingDuration;
      uint256 tgeAmount = percentage(totalAllocation, vestData.tgePercent);
      uint256 monthlyAmount =
        percentage(totalAllocation, vestData.monthlyPercent);
      providedVestAmount += _vestingAmounts[i];

      addUserVestingDetails(
        userAddress,
        vestIndexID,
        totalAllocation,
        lockPeriod,
        vestingDuration,
        tgeAmount,
        monthlyAmount
      );
    }
    uint256 ownerBalance = balanceOf(owner());
    require(
      ownerBalance >= providedVestAmount,
      "Owner does't have required token balance"
    );
    _transfer(owner(), address(this), providedVestAmount);
    return true;
  }

  /** @notice - Internal functions that is initializes the VestAllocation Struct with the respective arguments passed
   * @param _userAddresses addresses of the User
   * @param _totalAllocation total amount to be lockedUp
   * @param _vestingIndex denotes the type of vesting selected
   * @param _lockPeriod denotes the lock of the vesting category selcted
   * @param _vestingDuration denotes the total duration of the vesting category selcted
   * @param _tgeAmount denotes the total TGE amount to be transferred to the userVestingData
   * @param _monthlyAmount denotes the total Monthly Amount to be transferred to the user
   */

  function addUserVestingDetails(
    address _userAddresses,
    uint8 _vestingIndex,
    uint256 _totalAllocation,
    uint8 _lockPeriod,
    uint8 _vestingDuration,
    uint256 _tgeAmount,
    uint256 _monthlyAmount
  ) internal onlyValidVestingBenifciary(_userAddresses, _vestingIndex) {
    VestAllocation memory userVestingData =
      VestAllocation(
        _vestingIndex,
        _totalAllocation,
        _tgeAmount,
        _monthlyAmount,
        _vestingDuration,
        _lockPeriod,
        0,
        true,
        false
      );
    walletToVestAllocations[_userAddresses][_vestingIndex] = userVestingData;
  }

  /**
   * @notice Calculates the total amount of tokens Claimed by the User in a particular vesting category
   * @param _userAddresses address of the User
   * @param _vestingIndex index number of the vesting type
   */
  function totalTokensClaimed(address _userAddresses, uint8 _vestingIndex)
    public
    view
    returns (uint256)
  {
    // Get Vesting Details
    uint256 totalClaimedTokens;
    VestAllocation memory vestData =
      walletToVestAllocations[_userAddresses][_vestingIndex];

    totalClaimedTokens = totalClaimedTokens.add(
      vestData.totalVestTokensClaimed
    );

    if (vestData.isTgeTokensClaimed) {
      totalClaimedTokens = totalClaimedTokens.add(vestData.totalTGETokens);
    }

    return totalClaimedTokens;
  }

  /**
   * @notice An internal function to calculate the total claimable tokens at any given point
   * @param _userAddresses address of the User
   * @param _vestingIndex index number of the vesting type
   */

  function calculateClaimableVestTokens(
    address _userAddresses,
    uint8 _vestingIndex
  )
    public
    view
    checkVestingStatus(_userAddresses, _vestingIndex)
    returns (uint256)
  {
    // Get Vesting Details
    VestAllocation memory vestData =
      walletToVestAllocations[_userAddresses][_vestingIndex];

    // Get Time Details
    uint256 actualClaimableAmount;
    uint256 tokensAfterElapsedMonths;
    uint256 vestStartTime = getTGETime();
    uint256 currentTime = getCurrentTime();
    uint256 timeElapsed = currentTime.sub(vestStartTime);

    // Get the Elapsed Days and Months
    uint256 totalMonthsElapsed = timeElapsed.div(monthInSeconds());
    uint256 totalDaysElapsed = timeElapsed.div(daysInSeconds());
    uint256 partialDaysElapsed = totalDaysElapsed.mod(30);

    if (partialDaysElapsed > 0 && totalMonthsElapsed > 0) {
      totalMonthsElapsed += 1;
    }

    //Check whether or not the VESTING CLIFF has been reached
    require(
      totalMonthsElapsed > vestData.lockPeriod,
      "Vesting Cliff Not Crossed Yet"
    );

    // If total duration of Vesting already crossed, return pending tokens to claimed
    if (totalMonthsElapsed > vestData.vestingDuration) {
      uint256 _totalTokensClaimed =
        totalTokensClaimed(_userAddresses, _vestingIndex);
      actualClaimableAmount = vestData.totalTokensAllocated.sub(
        _totalTokensClaimed
      );
      // if current time has crossed the Vesting Cliff but not the total Vesting Duration
      // Calculating Actual Months(Excluding the CLIFF) to initiate vesting
    } else {
      uint256 actualMonthElapsed = totalMonthsElapsed.sub(vestData.lockPeriod);
      require(actualMonthElapsed > 0, "Number of months elapsed is ZERO");
      // Calculate the Total Tokens on the basis of Vesting Index and Month elapsed
      if (vestData.vestIndexID == 9) {
        uint256[4] memory monthsToRates;
        monthsToRates[1] = 20;
        monthsToRates[2] = 50;
        monthsToRates[3] = 80;
        tokensAfterElapsedMonths = percentage(
          vestData.totalTokensAllocated,
          monthsToRates[actualMonthElapsed]
        );
      } else {
        tokensAfterElapsedMonths = vestData.monthlyTokens.mul(
          actualMonthElapsed
        );
      }
      require(
        tokensAfterElapsedMonths > vestData.totalVestTokensClaimed,
        "No Claimable Tokens at this Time"
      );
      // Get the actual Claimable Tokens
      actualClaimableAmount = tokensAfterElapsedMonths.sub(
        vestData.totalVestTokensClaimed
      );
    }
    return actualClaimableAmount;
  }

  /**
   * @notice Function to transfer tokens from this contract to the user
   * @param _beneficiary address of the User
   * @param _amountOfTokens number of tokens to be transferred
   */
  function _sendTokens(address _beneficiary, uint256 _amountOfTokens)
    private
    returns (bool)
  {
    _transfer(address(this), _beneficiary, _amountOfTokens);
    return true;
  }

  /**
   * @notice Calculates and Transfer the total tokens to be transferred to the user after Token Generation Event is over
   * @dev The function shall only work for users under Sale Vesting Category(index - 7,8,9).
   * @dev The function can only be called once by the user(only if the isTgeTokensClaimed boolean value is FALSE).
   * Once the tokens have been transferred, isTgeTokensClaimed becomes TRUE for that particular address
   * @param _userAddresses address of the User
   * @param _vestingIndex index of the vesting Type
   */
  function claimTGETokens(address _userAddresses, uint8 _vestingIndex)
    public
    onlyAfterTGE
    whenNotPaused
    checkVestingStatus(_userAddresses, _vestingIndex)
    returns (bool)
  {
    // Get Vesting Details
    VestAllocation memory vestData =
      walletToVestAllocations[_userAddresses][_vestingIndex];

    require(
      vestData.vestIndexID >= 7 && vestData.vestIndexID <= 9,
      "Vesting Category doesn't belong to SALE VEsting"
    );
    require(
      vestData.isTgeTokensClaimed == false,
      "TGE Tokens Have already been claimed for Given Address"
    );

    uint256 tokensToTransfer = vestData.totalTGETokens;

    uint256 contractTokenBalance = balanceOf(address(this));
    require(
      contractTokenBalance >= tokensToTransfer,
      "Not Enough Token Balance in Contract"
    );

    // Updating Contract State
    vestData.isTgeTokensClaimed = true;
    walletToVestAllocations[_userAddresses][_vestingIndex] = vestData;
    _sendTokens(_userAddresses, tokensToTransfer);
  }

  /**
   * @notice Calculates and Transfers the total tokens to be transferred to the user by calculating the Amount of tokens to be transferred at the given time
   * @dev The function shall only work for users under Vesting Category is valid(index - 1 to 9).
   * @dev isVesting becomes false if all allocated tokens have been claimed.
   * @dev User cannot claim more tokens than actually allocated to them by the OWNER
   * @param _userAddresses address of the User
   * @param _vestingIndex index of the vesting Type
   * @param _tokenAmount the amount of tokens user wishes to withdraw
   */
  function claimVestTokens(
    address _userAddresses,
    uint8 _vestingIndex,
    uint256 _tokenAmount
  )
    public
    onlyAfterTGE
    whenNotPaused
    checkVestingStatus(_userAddresses, _vestingIndex)
    returns (bool)
  {
    // Get Vesting Details
    VestAllocation memory vestData =
      walletToVestAllocations[_userAddresses][_vestingIndex];

    // Get total amount of tokens claimed till date
    uint256 _totalTokensClaimed =
      totalTokensClaimed(_userAddresses, _vestingIndex);
    // Get the total claimable token amount at the time of calling this function
    uint256 tokensToTransfer =
      calculateClaimableVestTokens(_userAddresses, _vestingIndex);

    require(
      tokensToTransfer > 0,
      "No tokens to transfer at this point of time"
    );
    require(
      _tokenAmount <= tokensToTransfer,
      "Cannot Claim more than Monthly Vest Amount"
    );
    uint256 contractTokenBalance = balanceOf(address(this));
    require(
      contractTokenBalance >= _tokenAmount,
      "Not Enough Token Balance in Contract"
    );
    require(
      _totalTokensClaimed.add(_tokenAmount) <= vestData.totalTokensAllocated,
      "Cannot Claim more than Allocated"
    );

    vestData.totalVestTokensClaimed += _tokenAmount;
    if (
      _totalTokensClaimed.add(_tokenAmount) == vestData.totalTokensAllocated
    ) {
      vestData.isVesting = false;
    }
    walletToVestAllocations[_userAddresses][_vestingIndex] = vestData;
    _sendTokens(_userAddresses, _tokenAmount);
  }

  // Commented Out the withdraw function
  // function withdrawContractTokens() external onlyOwner returns (bool) {
  //   uint256 remainingTokens = balanceOf(address(this));
  //   _sendTokens(owner(), remainingTokens);
  // }
}
