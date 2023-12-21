pragma solidity >=0.7.0 <0.9.0;

import "./storage.sol";

contract Owned is Storage {
    
    // -----------------------------------------------------
    // Usual storage
    // -----------------------------------------------------

    // mapping(address => bool) public owner;

    // -----------------------------------------------------
    // Events
    // -----------------------------------------------------

    event AddedOwner(address newOwner);
    event RemovedOwner(address removedOwner);

    // -----------------------------------------------------
    // storage utilities
    // -----------------------------------------------------

    function _isOwner(address _caller) internal view returns (bool) {
        return getBool(keccak256(abi.encode("owner",_caller)));
    }

    function _addOwner(address _newOwner) internal {
        // Add owner to list
        address[] storage owners = getOwners();
        owners.push(_newOwner);
        setOwners(owners);

        // Set owner bool in storage
        setBool(keccak256(abi.encode("owner", _newOwner)), true);
    }

    function _deleteOwner(address _owner) internal {
        // Remove owner from list
        address[] storage owners = getOwners();
        for (uint i=0; i<owners.length - 1; i++)
            if (owners[i] == _owner) {
                owners[i] = owners[owners.length - 1];
                break;
            }
        owners.pop();
        setOwners(owners);

        // Delete owner bool from storage
        deleteBool(keccak256(abi.encode("owner", _owner)));
    }

    function setOwners(address[] storage _addresses) internal {
        setAddresses(keccak256(abi.encode("owners")), _addresses);
    }

    function getOwners() internal view returns (address[] storage) {
        return getAddresses(keccak256(abi.encode("owners")));
    }

    // -----------------------------------------------------
    // Main contract
    // -----------------------------------------------------

    constructor() {
        _addOwner(msg.sender);
    }

    modifier onlyOwner() {
        require(_isOwner(msg.sender));
        _;
    }

    function addOwner(address _newOwner) onlyOwner public {
        require(!_isOwner(_newOwner));
        require(_newOwner != address(0));
        _addOwner(_newOwner);
        emit AddedOwner(_newOwner);
    }

    function removeOwner(address _toRemove) onlyOwner public {
        require(_isOwner(_toRemove));
        require(_toRemove != address(0));
        require(_toRemove != msg.sender);
        _deleteOwner(_toRemove);
        emit RemovedOwner(_toRemove);
    }

    function owners_list() public view returns (address[] memory) {
        return getOwners();
    }

    function is_owner(address owner) public view returns (bool) {
        return _isOwner(owner);
    }
}