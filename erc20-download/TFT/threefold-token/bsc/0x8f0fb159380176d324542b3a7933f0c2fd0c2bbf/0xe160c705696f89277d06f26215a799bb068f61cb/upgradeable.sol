pragma solidity >=0.7.0 <0.9.0;

import "./owned.sol";

contract Upgradeable is Owned {
    // -----------------------------------------------------
    // Usual storage
    // -----------------------------------------------------

    // string internal _version;
    // address internal _implementation;

    // -----------------------------------------------------
    // Events
    // -----------------------------------------------------

    event Upgraded(string indexed version, address indexed implementation);

    // -----------------------------------------------------
    // storage utilities
    // -----------------------------------------------------

    function _getVersion() internal view returns (string memory) {
        return getString(keccak256(abi.encode("version")));
    }

    function _setVersion(string memory _version) internal {
        setString(keccak256(abi.encode("version")), _version);
    }

    function _getImplementation() internal view returns (address) {
        return getAddress(keccak256(abi.encode("implementation")));
    }

    function _setImplementation(address _implementation) internal {
        setAddress(keccak256(abi.encode("implementation")), _implementation);
    }

    // -----------------------------------------------------
    // Main contract
    // -----------------------------------------------------

    function version() public view returns (string memory) {
        return _getVersion();
    }

    function implementation() public view returns (address) {
        return _getImplementation();
    }


    function upgradeTo(string memory _version, address _implementation) public onlyOwner {
        require(_getImplementation() != _implementation);
        _setVersion(_version);
        _setImplementation(_implementation);
        emit Upgraded(_version, _implementation);
    }
}