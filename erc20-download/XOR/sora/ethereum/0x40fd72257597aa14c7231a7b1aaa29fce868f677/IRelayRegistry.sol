pragma solidity ^0.5.8;

/**
 * @title Relay registry interface
 */
interface IRelayRegistry {

    /**
     * Store relay address and appropriate whitelist of addresses
     * @param relay contract address
     * @param whiteList with allowed addresses
     * @return true if data was stored
     */
    function addNewRelayAddress(address relay, address[] calldata whiteList) external;

    /**
     * Check if some address is in the whitelist
     * @param relay contract address
     * @param who address in whitelist
     * @return true if address in the whitelist
     */
    function isWhiteListed(address relay, address who) external view returns (bool);

    /**
     * Get entire whitelist by relay address
     * @param relay contract address
     * @return array of the whitelist
     */
    function getWhiteListByRelay(address relay) external view returns (address[] memory);

    event AddNewRelay (
        address indexed relayAddress,
        address[] indexed whiteList
    );
}
