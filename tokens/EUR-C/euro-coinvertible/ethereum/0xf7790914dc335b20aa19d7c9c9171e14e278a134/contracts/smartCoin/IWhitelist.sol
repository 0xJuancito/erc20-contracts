pragma solidity 0.8.17;

interface IWhitelist {
    event WhitelistedAddressAdded(address addr);
    event WhitelistedAddressRemoved(address addr);
    event RegistrarUpdated(
        address indexed previousRegistrar,
        address indexed newRegistrar
    );

    function updateRegistrar(address newRegistrar) external returns (bool);

    function addAddressToWhitelist(address holder) external returns (bool);

    function removeAddressFromWhitelist(address holder) external returns (bool);
}
