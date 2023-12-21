// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

/**
 * Reference from https://github.com/crypto-org-chain/cronos-public-contracts/blob/master/CROBridge/CROBridge.sol
 */
interface ICroBridge {
    // Pay the contract a certain CRO amount and trigger a CRO transfer
    // from the contract to recipient through IBC
    function send_cro_to_crypto_org(string memory recipient) external payable;
}
