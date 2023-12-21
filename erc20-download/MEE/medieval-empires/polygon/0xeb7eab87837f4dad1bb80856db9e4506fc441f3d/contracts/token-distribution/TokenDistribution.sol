// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity 0.8.17;

contract TokenDistribution {
    enum RoundType {
        SEED, PRIVATE, PUBLIC, PLAYANDEARN, EXCHANGES, TREASURY, ADVISOR, TEAM, SOCIAL
    }

    struct Distribution {
        uint256 vestingPeriod; // seconds
        uint256 cliff; // seconds
        uint256 totalRemaining;
        uint256 supply;
        uint256 vestingGranularity;
    }

    uint internal maxSupply;

    function getRoundTypeByKey(string memory _roundType) internal pure returns (RoundType) {
        bytes memory roundType = bytes(_roundType);
        bytes32 hash = keccak256(roundType);

        if (hash == keccak256("SEED") || hash == keccak256("seed")) return RoundType.SEED;
        if (hash == keccak256("PRIVATE") || hash == keccak256("private")) return RoundType.PRIVATE;
        if (hash == keccak256("PUBLIC") || hash == keccak256("public")) return RoundType.PUBLIC;
        if (hash == keccak256("PLAYANDEARN") || hash == keccak256("playandearn")) return RoundType.PLAYANDEARN;
        if (hash == keccak256("EXCHANGES") || hash == keccak256("exchanges")) return RoundType.EXCHANGES;
        if (hash == keccak256("TREASURY") || hash == keccak256("treasury")) return RoundType.TREASURY;
        if (hash == keccak256("ADVISOR") || hash == keccak256("advisor")) return RoundType.ADVISOR;
        if (hash == keccak256("TEAM") || hash == keccak256("team")) return RoundType.TEAM;
        if (hash == keccak256("SOCIAL") || hash == keccak256("social")) return RoundType.SOCIAL;
        revert();
    }
}
