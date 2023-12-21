pragma solidity 0.8.17;

import "./IWhitelist.sol";

abstract contract Whitelist is IWhitelist {
    mapping(address => bool) public whitelist;
    address public registrar;

    constructor(address registrarAddress) {
        registrar = registrarAddress;
    }

    /**
     * @dev Throws if called by any account that's not whitelisted.
     */
    modifier onlyWhitelisted(address _addr) {
        require(whitelist[_addr], "Whitelist: address must be whitelisted");
        _;
    }
    /**
     * @dev Throws if called by any account other than the registrar.
     */
    modifier onlyRegistrar() {
        require(
            msg.sender == registrar,
            "Whitelist: Only registrar could perform that action"
        );
        _;
    }

    /**
     * @dev Allows the current registrar to transfer control of the contract to a newRegistrar.
     * @param _newRegistrar The address to transfer registrarship to.
     */
    function updateRegistrar(address _newRegistrar)
        external
        onlyRegistrar
        returns (bool)
    {
        require(
            _newRegistrar != address(0),
            "Whitelist: new registrar is the zero address"
        );
        return _transferRegistrarship(_newRegistrar);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newRegistrar`).
     * Internal function without access restriction.
     */
    function _transferRegistrarship(address _newRegistrar)
        internal
        virtual
        returns (bool)
    {
        address oldRegistrar = registrar;
        registrar = _newRegistrar;
        emit RegistrarUpdated(oldRegistrar, _newRegistrar);
        return true;
    }

    /**
     * @dev add an address to the whitelist
     * @param _addr address
     * @return true if the address was added to the whitelist, false if the address was already in the whitelist
     */
    function addAddressToWhitelist(address _addr)
        external
        onlyRegistrar
        returns (bool)
    {
        require(!whitelist[_addr], "Whitelist: Address already whitelisted");
        whitelist[_addr] = true;
        emit WhitelistedAddressAdded(_addr);
        return true;
    }

    /**
     * @dev remove an address from the whitelist
     * @param _addr address
     * @return true if the address was removed from the whitelist,
     * false if the address wasn't in the whitelist in the first place
     */
    function removeAddressFromWhitelist(address _addr)
        external
        onlyRegistrar
        returns (bool)
    {
        require(whitelist[_addr], "Whitelist: Address not whitelisted");
        whitelist[_addr] = false;
        emit WhitelistedAddressRemoved(_addr);
        return true;
    }
}
