pragma solidity ^0.5.8;

import "./IRelayRegistry.sol";

/**
 * @title Relay registry store data about white list and provide interface for master
 */
contract RelayRegistry is IRelayRegistry {
    bool internal initialized_;
    address private owner_;

    mapping(address => address[]) private _relayWhiteList;

    constructor () public {
        initialize(msg.sender);
    }

    /**
     * Initialization of smart contract.
     */
    function initialize(address owner) public {
        require(!initialized_);
        owner_ = owner;
        initialized_ = true;
    }

    /**
     * Store relay address and appropriate whitelist of addresses
     * @param relay contract address
     * @param whiteList white list
     */
    function addNewRelayAddress(address relay, address[] calldata whiteList) external {
        require(msg.sender == owner_);
        require(_relayWhiteList[relay].length == 0);
        _relayWhiteList[relay] = whiteList;
        emit AddNewRelay(relay, whiteList);
    }

    /**
     * Check if some address is in the whitelist
     * @param relay contract address
     * @param who address in whitelist
     * @return true if address in the whitelist
     */
    function isWhiteListed(address relay, address who) external view returns (bool) {
        if (_relayWhiteList[relay].length == 0) {
            return true;
        }
        if (_relayWhiteList[relay].length > 0) {
            for (uint i = 0; i < _relayWhiteList[relay].length; i++) {
                if (who == _relayWhiteList[relay][i]) {
                    return true;
                }
            }
        }
        return false;
    }

    /**
     * Get entire whitelist by relay address
     * @param relay contract address
     * @return array of the whitelist
     */
    function getWhiteListByRelay(address relay) external view returns (address[] memory ) {
        require(relay != address(0));
        require(_relayWhiteList[relay].length != 0);
        return _relayWhiteList[relay];
    }
}
