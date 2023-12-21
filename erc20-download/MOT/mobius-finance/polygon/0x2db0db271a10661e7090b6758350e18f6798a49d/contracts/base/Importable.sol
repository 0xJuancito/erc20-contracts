// SPDX-License-Identifier: MIT
pragma solidity =0.8.4;

import './Ownable.sol';
import '../interfaces/IResolver.sol';
import '../lib/Strings.sol';

contract Importable is Ownable {
    using Strings for string;

    IResolver public resolver;
    bytes32[] internal imports;

    mapping(bytes32 => address) private _cache;

    constructor(IResolver _resolver) {
        resolver = _resolver;
    }

    modifier onlyAddress(bytes32 name) {
        require(msg.sender == _cache[name], contractName.concat(': caller is not the ', name));
        _;
    }

    modifier containAddress(bytes32[] memory names) {
        require(names.length < 20, contractName.concat(': cannot have more than 20 items'));

        bool contain = false;
        for (uint256 i = 0; i < names.length; i++) {
            if (msg.sender == _cache[names[i]]) {
                contain = true;
                break;
            }
        }
        require(contain, contractName.concat(': caller is not in contains'));
        _;
    }

    modifier containAddressOrOwner(bytes32[] memory names) {
        require(names.length < 20, contractName.concat(': cannot have more than 20 items'));

        bool contain = false;
        for (uint256 i = 0; i < names.length; i++) {
            if (msg.sender == _cache[names[i]]) {
                contain = true;
                break;
            }
        }
        if (!contain) contain = (msg.sender == owner);
        require(contain, contractName.concat(': caller is not in dependencies'));
        _;
    }

    function refreshCache() external onlyOwner {
        for (uint256 i = 0; i < imports.length; i++) {
            bytes32 item = imports[i];
            _cache[item] = resolver.getAddress(item);
        }
    }

    function getImports() external view returns (bytes32[] memory) {
        return imports;
    }

    function requireAsset(bytes32 assetType, bytes32 assetName) internal view returns (address) {
        (bool exist, address assetAddress) = resolver.getAsset(assetType, assetName);
        require(exist, contractName.concat(': Missing Asset Token ', assetName));
        return assetAddress;
    }

    function assets(bytes32 assetType) internal view returns (bytes32[] memory) {
        return resolver.getAssets(assetType);
    }

    function addAddress(bytes32 name) external onlyOwner {
        _cache[name] = resolver.getAddress(name);
        imports.push(name);
    }

    function requireAddress(bytes32 name) internal view returns (address) {
        require(_cache[name] != address(0), contractName.concat(': Missing ', name));
        return _cache[name];
    }

    function getAddress(bytes32 name) external view returns (address) {
        return _cache[name];
    }
}
