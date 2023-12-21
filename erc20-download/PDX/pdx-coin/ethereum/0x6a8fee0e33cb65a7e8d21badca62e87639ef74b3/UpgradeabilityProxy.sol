pragma solidity ^0.5.0;

import "./Proxy.sol";
import "./UpgradeabilityStorage.sol";

contract UpgradeabilityProxy is Proxy, UpgradeabilityStorage {
    function admin() public view returns (address);

    event Upgraded(string version, address indexed implementation);

    function upgradeTo(string memory version, address implementation) public {
        require(msg.sender == admin());
        require(_implementation != implementation);
        _version = version;
        _implementation = implementation;
        emit Upgraded(version, implementation);
    }
}