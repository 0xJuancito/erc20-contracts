// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

enum MintAction {
    CLAIM,
    BURN
}
enum MintStatus {
    ACTIVE,
    CLAIMED,
    BURNED
}
enum StakeAction {
    START,
    END,
    BURN,
    END_OWN,
    END_OTHER
}
enum StakeStatus {
    ACTIVE,
    ENDED,
    BURNED
}
enum PayoutTriggered {
    NO,
    YES
}
enum InitialLPMinted {
    NO,
    YES
}
enum PayoutClaim {
    SHARES,
    BURN
}
enum BurnSource {
    LIQUID,
    MINT,
    STAKE
}
enum BurnPoolEnabled {
    FALSE,
    TRUE
}
