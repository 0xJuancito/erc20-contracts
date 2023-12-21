// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

// NOTE: we ignore leap-seconds etc.
library MintMath {
    // The maximum number of seconds per month (365 * 24 * 60 * 60 / 12)
    uint32 public constant SECONDS_PER_MONTH = 2628000;
    // The maximum number of days PRPS can be finitely locked for
    uint16 public constant MAX_FINITE_LOCK_DURATION_DAYS = 365;
    // The maximum number of seconds PRPS can be finitely locked for
    uint32 public constant MAX_FINITE_LOCK_DURATION_SECONDS =
        uint32(MAX_FINITE_LOCK_DURATION_DAYS) * 24 * 60 * 60;

    /**
     * @dev Calculates the DUBI to mint based on the given amount of PRPS and duration in days.
     * NOTE: We trust the caller to ensure that the duration between 1 and 365.
     */
    function calculateDubiToMintByDays(
        uint256 amountPrps,
        uint16 durationInDays
    ) internal pure returns (uint96) {
        uint32 durationInSeconds = uint32(durationInDays) * 24 * 60 * 60;
        return calculateDubiToMintBySeconds(amountPrps, durationInSeconds);
    }

    /**
     * @dev Calculates the DUBI to mint based on the given amount of PRPS and duration in seconds.
     */
    function calculateDubiToMintBySeconds(
        uint256 amountPrps,
        uint32 durationInSeconds
    ) internal pure returns (uint96) {
        uint256 _percentage = percentage(
            durationInSeconds,
            MAX_FINITE_LOCK_DURATION_SECONDS,
            18 // precision in WEI, 10^18
        ) * 4; // A full lock grants 4%, so multiply by 4.

        // Multiply PRPS by the percentage and then divide by the precision (=10^8)
        // from the previous step
        uint256 _dubiToMint = (amountPrps * _percentage) / (1 ether * 100); // multiply by 100, because we deal with percentages

        // Assert that the calculated DUBI never overflows uint96
        assert(_dubiToMint < 2**96);

        return uint96(_dubiToMint);
    }

    function calculateDubiToMintMax(uint96 amount)
        internal
        pure
        returns (uint96)
    {
        return
            calculateDubiToMintBySeconds(
                amount,
                MAX_FINITE_LOCK_DURATION_SECONDS
            );
    }

    function calculateMintDuration(uint32 _now, uint32 lastWithdrawal)
        internal
        pure
        returns (uint32)
    {
        require(lastWithdrawal > 0 && lastWithdrawal <= _now, "MINT-1");

        uint256 _elapsedTotal = _now - lastWithdrawal;
        uint256 _proRatedYears = _elapsedTotal / SECONDS_PER_MONTH / 12;
        uint256 _elapsedInYear = _elapsedTotal %
            MAX_FINITE_LOCK_DURATION_SECONDS;

        //
        // Examples (using months instead of seconds):
        // calculation formula: (monthsSinceWithdrawal % 12) + (_proRatedYears * 12)

        // 1) Burn after 11 months since last withdrawal (number of years = 11 / 12 + 1 = 1)
        // => (11 % 12) + (years * 12) => 23 months worth of DUBI
        // => 23 months

        // 1) Burn after 4 months since last withdrawal (number of years = 4 / 12 + 1 = 1)
        // => (4 % 12) + (years * 12) => 16 months worth of DUBI
        // => 16 months

        // 2) Burn 0 months after withdrawal after 4 months (number of years = 0 / 12 + 1 = 1):
        // => (0 % 12) + (years * 12) => 12 months worth of DUBI (+ 4 months worth of withdrawn DUBI)
        // => 16 months

        // 3) Burn after 36 months since last withdrawal (number of years = 36 / 12 + 1 = 4)
        // => (36 % 12) + (years * 12) => 48 months worth of DUBI
        // => 48 months

        // 4) Burn 1 month after withdrawal after 35 months (number of years = 1 / 12 + 1 = 1):
        // => (1 % 12) + (years * 12) => 12 month worth of DUBI (+ 35 months worth of withdrawn DUBI)
        // => 47 months
        uint32 _mintDuration = uint32(
            _elapsedInYear + _proRatedYears * MAX_FINITE_LOCK_DURATION_SECONDS
        );

        return _mintDuration;
    }

    function percentage(
        uint256 numerator,
        uint256 denominator,
        uint256 precision
    ) internal pure returns (uint256) {
        return
            ((numerator * (uint256(10)**(precision + 1))) / denominator + 5) /
            uint256(10);
    }
}
