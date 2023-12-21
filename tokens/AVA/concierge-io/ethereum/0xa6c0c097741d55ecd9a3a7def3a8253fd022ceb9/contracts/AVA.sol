// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract AVA is ERC20PresetMinterPauser {
    struct YearlyMintInfo {
        uint256 maxMintAmount;
        uint256 currentMintAmount;
        uint256 remainingMintAmount;
    }

    uint256 private constant YEAR_DURATION = 365 days;
    uint256 public immutable startTime;

    uint256 private constant E18 = 10 ** 18;
    uint256 private immutable STARTING_SUPPLY;

    // Can only be increased after 10-period
    uint256 public MAX_SUPPLY;

    // yearID (e.g. 11 or 12) => true/false
    mapping(uint256 => bool) public maxSupplyAlreadyIncreased;
    uint256 public constant PERCENT_BASE = 10_000;

    uint256 public constant MAX_MINT_AMOUNT_YEAR_1 = 4_469_096;
    uint256 public constant MAX_MINT_AMOUNT_YEAR_2 = 4_469_056;
    uint256 public constant MAX_MINT_AMOUNT_YEAR_3 = 4_424_322;
    uint256 public constant MAX_MINT_AMOUNT_YEAR_4 = 4_332_292;
    uint256 public constant MAX_MINT_AMOUNT_YEAR_5 = 4_191_118;
    uint256 public constant MAX_MINT_AMOUNT_YEAR_6 = 3_999_810;
    uint256 public constant MAX_MINT_AMOUNT_YEAR_7 = 3_758_316;
    uint256 public constant MAX_MINT_AMOUNT_YEAR_8 = 3_467_587;
    uint256 public constant MAX_MINT_AMOUNT_YEAR_9 = 3_129_608;
    uint256 public constant MAX_MINT_AMOUNT_YEAR_10 = 2_747_405;

    // yearID (e.g. 1 or 2) => YearlyMintInfo
    mapping(uint256 => YearlyMintInfo) public inflationaryModelPerYear;
    uint256 public inflationaryModelTotalYears;

    event EvtUpdateInflationaryModelPerYear(
        uint256 yearID,
        uint256 maxMintAmount
    );
    event EvtAddNewYearForInflationaryModel(
        uint256 newYearID,
        uint256 maxMintAmount
    );
    event EvtIncreaseMaxSupply(uint256 maxSupplyIncreasingPercent);
    event EvtMintCurrentYear(address to, uint256 amount, uint256 currentYearID);
    event EvtMintRemainingCurrentYear(
        address to,
        uint256 amount,
        uint256 currentYearID
    );
    event EvtMintRemainingPastYear(
        address to,
        uint256 amount,
        uint256 pastYearID
    );

    constructor(
        address startingSupplyReceiverWallet
    ) ERC20PresetMinterPauser("AVA", "AVA") {
        require(
            startingSupplyReceiverWallet != address(0),
            "AVA: startingSupplyReceiverWallet invalid"
        );
        STARTING_SUPPLY = 61_011_389 * E18;
        MAX_SUPPLY = 100_000_000 * E18;
        startTime = block.timestamp;

        // Initial mint with the specified starting supply
        super.mint(startingSupplyReceiverWallet, STARTING_SUPPLY);

        // Define the inflationary model
        inflationaryModelPerYear[1] = YearlyMintInfo(
            MAX_MINT_AMOUNT_YEAR_1,
            0,
            MAX_MINT_AMOUNT_YEAR_1
        );
        inflationaryModelPerYear[2] = YearlyMintInfo(
            MAX_MINT_AMOUNT_YEAR_2,
            0,
            MAX_MINT_AMOUNT_YEAR_2
        );
        inflationaryModelPerYear[3] = YearlyMintInfo(
            MAX_MINT_AMOUNT_YEAR_3,
            0,
            MAX_MINT_AMOUNT_YEAR_3
        );
        inflationaryModelPerYear[4] = YearlyMintInfo(
            MAX_MINT_AMOUNT_YEAR_4,
            0,
            MAX_MINT_AMOUNT_YEAR_4
        );
        inflationaryModelPerYear[5] = YearlyMintInfo(
            MAX_MINT_AMOUNT_YEAR_5,
            0,
            MAX_MINT_AMOUNT_YEAR_5
        );
        inflationaryModelPerYear[6] = YearlyMintInfo(
            MAX_MINT_AMOUNT_YEAR_6,
            0,
            MAX_MINT_AMOUNT_YEAR_6
        );
        inflationaryModelPerYear[7] = YearlyMintInfo(
            MAX_MINT_AMOUNT_YEAR_7,
            0,
            MAX_MINT_AMOUNT_YEAR_7
        );
        inflationaryModelPerYear[8] = YearlyMintInfo(
            MAX_MINT_AMOUNT_YEAR_8,
            0,
            MAX_MINT_AMOUNT_YEAR_8
        );
        inflationaryModelPerYear[9] = YearlyMintInfo(
            MAX_MINT_AMOUNT_YEAR_9,
            0,
            MAX_MINT_AMOUNT_YEAR_9
        );
        inflationaryModelPerYear[10] = YearlyMintInfo(
            MAX_MINT_AMOUNT_YEAR_10,
            0,
            MAX_MINT_AMOUNT_YEAR_10
        );

        inflationaryModelTotalYears = 10;
    }

    // Only admin role can update the inflationary model
    function updateInflationaryModelPerYear(
        uint256 yearID,
        uint256 maxMintAmount
    ) external {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "AVA: must have admin role to set the inflationary model"
        );
        require(yearID > 0, "AVA: yearID must be positive");
        uint256 currentYear = getCurrentYear();
        require(
            yearID >= currentYear,
            "AVA: yearID must be from current year afterwards"
        );

        require(maxMintAmount > 0, "AVA: maxMintAmount must be positive");
        require(
            (ERC20.totalSupply() + (maxMintAmount * E18)) <= MAX_SUPPLY,
            "AVA: maxMintAmount invalid as max supply exceeded"
        );

        require(
            inflationaryModelPerYear[yearID].maxMintAmount > 0,
            "AVA: inflationary model for the given year not exist"
        );

        require(
            maxMintAmount >= inflationaryModelPerYear[yearID].currentMintAmount,
            "AVA: maxMintAmount invalid as smaller than currentMintAmount"
        );
        inflationaryModelPerYear[yearID].maxMintAmount = maxMintAmount;
        inflationaryModelPerYear[yearID].remainingMintAmount =
            maxMintAmount -
            inflationaryModelPerYear[yearID].currentMintAmount;

        emit EvtUpdateInflationaryModelPerYear(yearID, maxMintAmount);
    }

    // Only admin role can add new inflationary model
    function addNewYearForInflationaryModel(uint256 maxMintAmount) external {
        uint256 currentYear = getCurrentYear();
        require(
            currentYear > 10,
            "AVA: cannot add new inflationary model before 10-year period"
        );
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "AVA: must have admin role to set the inflationary model"
        );
        require(maxMintAmount > 0, "AVA: maxMintAmount must be positive");
        require(
            (ERC20.totalSupply() + (maxMintAmount * E18)) <= MAX_SUPPLY,
            "AVA: maxMintAmount invalid as max supply exceeded"
        );

        inflationaryModelTotalYears++;

        if (currentYear > inflationaryModelTotalYears) {
            inflationaryModelTotalYears = currentYear;
        }

        inflationaryModelPerYear[inflationaryModelTotalYears] = YearlyMintInfo(
            maxMintAmount,
            0,
            maxMintAmount
        );

        emit EvtAddNewYearForInflationaryModel(
            inflationaryModelTotalYears,
            maxMintAmount
        );
    }

    // 1 for year 1
    // 2 for year 2
    function getCurrentYear() public view returns (uint256) {
        uint256 currentYear = ((block.timestamp - startTime) / YEAR_DURATION) +
            1;
        return currentYear;
    }

    function getInflationayModelCurrentYear()
        external
        view
        returns (uint256, uint256, uint256)
    {
        uint256 currentYear = getCurrentYear();
        return (
            inflationaryModelPerYear[currentYear].maxMintAmount,
            inflationaryModelPerYear[currentYear].currentMintAmount,
            inflationaryModelPerYear[currentYear].remainingMintAmount
        );
    }

    // After 10 years, it's possible to increase the max supply by the specified percent
    // Example: 280 for 2.8% or 430 for 4.3%
    function increaseMaxSupply(uint256 maxSupplyIncreasingPercent) external {
        uint256 currentYear = getCurrentYear();
        require(
            currentYear > 10,
            "AVA: cannot increase max supply before 10-year period"
        );
        require(
            !maxSupplyAlreadyIncreased[currentYear],
            "AVA: max supply can only be increased once in a year"
        );
        require(
            maxSupplyIncreasingPercent > 0,
            "AVA: maxSupplyIncreasingPercent must be > 0%"
        );
        require(
            maxSupplyIncreasingPercent < PERCENT_BASE,
            "AVA: maxSupplyIncreasingPercent must be < 100%"
        );

        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "AVA: must have admin role to set the max supply"
        );

        MAX_SUPPLY +=
            (maxSupplyIncreasingPercent * ERC20.totalSupply()) /
            PERCENT_BASE;

        maxSupplyAlreadyIncreased[currentYear] = true;

        emit EvtIncreaseMaxSupply(maxSupplyIncreasingPercent);
    }

    // At any time within the current year, only MINTER_ROLE wallet can mint
    // the amount of tokens for multiple times as long as the maxMintAmount
    // of the current year is not exceeded.
    // Max supply must also be respected.
    function mintCurrentYear(address to, uint256 amount) public {
        require(to != address(0), "AVA: invalid to address");
        require(amount > 0, "AVA: amount must be positive");

        uint256 amountE18 = amount * E18;
        require(
            (ERC20.totalSupply() + amountE18) <= MAX_SUPPLY,
            "AVA: max supply exceeded"
        );

        uint256 currentYear = getCurrentYear();
        require(
            inflationaryModelPerYear[currentYear].maxMintAmount > 0,
            "AVA: inflationary model for the current year not set"
        );
        require(
            inflationaryModelPerYear[currentYear].remainingMintAmount > 0,
            "AVA: no further mint possible for the current year"
        );
        require(
            inflationaryModelPerYear[currentYear].remainingMintAmount >= amount,
            "AVA: amount exceeds the remainingMintAmount for the current year"
        );

        super.mint(to, amountE18);

        inflationaryModelPerYear[currentYear].currentMintAmount += amount;

        inflationaryModelPerYear[currentYear].remainingMintAmount -= amount;

        emit EvtMintCurrentYear(to, amount, currentYear);
    }

    // At any time within the current year, only MINTER_ROLE wallet can mint
    // the remaining tokens (if any) at once
    function mintRemainingCurrentYear(address to) external {
        require(to != address(0), "AVA: invalid to address");
        uint256 currentYear = getCurrentYear();
        uint256 amount = inflationaryModelPerYear[currentYear]
            .remainingMintAmount;
        require(
            amount > 0,
            "AVA: no further remaining tokens of the current year to mint"
        );
        mintCurrentYear(to, amount);

        emit EvtMintRemainingCurrentYear(to, amount, currentYear);
    }

    // At any time, only MINTER_ROLE wallet can mint
    // the remaining tokens (if any) of the specified past year
    function mintRemainingPastYear(address to, uint256 pastYearID) external {
        require(to != address(0), "AVA: invalid to address");
        require(pastYearID > 0, "AVA: pastYearID must be positive");

        uint256 currentYear = getCurrentYear();
        require(pastYearID < currentYear, "AVA: pastYearID is not a past year");

        require(
            inflationaryModelPerYear[pastYearID].maxMintAmount > 0,
            "AVA: inflationary model for the given pastYearID not exist"
        );

        uint256 amount = inflationaryModelPerYear[pastYearID]
            .remainingMintAmount;
        require(
            amount > 0,
            "AVA: no further remaining tokens of the specified past year to mint"
        );

        uint256 amountE18 = amount * E18;
        require(
            (ERC20.totalSupply() + amountE18) <= MAX_SUPPLY,
            "AVA: max supply exceeded"
        );

        super.mint(to, amountE18);

        inflationaryModelPerYear[pastYearID].currentMintAmount += amount;
        inflationaryModelPerYear[pastYearID].remainingMintAmount -= amount;

        emit EvtMintRemainingPastYear(to, amount, pastYearID);
    }

    function mint(address to, uint256 amount) public override {
        mintCurrentYear(to, amount);
    }
}
