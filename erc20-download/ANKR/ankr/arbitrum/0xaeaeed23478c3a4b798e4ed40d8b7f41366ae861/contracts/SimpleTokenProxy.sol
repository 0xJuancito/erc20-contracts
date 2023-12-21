// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.6;

import "./interfaces/ICrossChainBridge.sol";

contract SimpleTokenProxy {

    bytes32 private constant BEACON_SLOT = bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1);

    fallback() external {
        address bridge;
        bytes32 slot = BEACON_SLOT;
        assembly {
            bridge := sload(slot)
        }
        address impl = ICrossChainBridge(bridge).getTokenImplementation();
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {revert(0, returndatasize())}
            default {return (0, returndatasize())}
        }
    }

    function setBeacon(address newBeacon) external {
        address beacon;
        bytes32 slot = BEACON_SLOT;
        assembly {
            beacon := sload(slot)
        }
        require(beacon == address(0x00));
        assembly {
            sstore(slot, newBeacon)
        }
    }
}

library SimpleTokenProxyUtils {

    bytes constant internal SIMPLE_TOKEN_PROXY_BYTECODE = hex"608060405234801561001057600080fd5b50610215806100206000396000f3fe608060405234801561001057600080fd5b506004361061002b5760003560e01c8063d42afb56146100fd575b60008061005960017fa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d516101a2565b60001b9050805491506000826001600160a01b031663709bc7f36040518163ffffffff1660e01b8152600401602060405180830381600087803b15801561009f57600080fd5b505af11580156100b3573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906100d79190610185565b90503660008037600080366000845af43d6000803e8080156100f8573d6000f35b3d6000fd5b61011061010b366004610161565b610112565b005b60008061014060017fa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d516101a2565b8054925090506001600160a01b0382161561015a57600080fd5b9190915550565b60006020828403121561017357600080fd5b813561017e816101c7565b9392505050565b60006020828403121561019757600080fd5b815161017e816101c7565b6000828210156101c257634e487b7160e01b600052601160045260246000fd5b500390565b6001600160a01b03811681146101dc57600080fd5b5056fea2646970667358221220e6ae4b3dc2474e43ff609e19eb520ce54b6f38170a43a6f96541360be5efc2b464736f6c63430008060033";

    bytes32 constant internal SIMPLE_TOKEN_PROXY_HASH = keccak256(SIMPLE_TOKEN_PROXY_BYTECODE);

    bytes4 constant internal SET_META_DATA_SIG = bytes4(keccak256("initAndObtainOwnership(bytes32,bytes32,uint256,address)"));
    bytes4 constant internal SET_BEACON_SIG = bytes4(keccak256("setBeacon(address)"));

    function deploySimpleTokenProxy(address bridge, bytes32 salt, ICrossChainBridge.Metadata memory metaData) internal returns (address) {
        /* lets concat bytecode with constructor parameters */
        bytes memory bytecode = SIMPLE_TOKEN_PROXY_BYTECODE;
        /* deploy new contract and store contract address in result variable */
        address result;
        assembly {
            result := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        require(result != address(0x00), "deploy failed");
        /* setup impl */
        (bool success,) = result.call(abi.encodePacked(SET_BEACON_SIG, abi.encode(bridge)));
        require(success, "setBeacon failed");
        /* setup meta data */
        (success,) = result.call(abi.encodePacked(SET_META_DATA_SIG, abi.encode(metaData)));
        require(success, "set metadata failed");
        /* return generated contract address */
        return result;
    }

    function simpleTokenProxyAddress(address deployer, bytes32 salt) internal pure returns (address) {
        bytes32 bytecodeHash = keccak256(SIMPLE_TOKEN_PROXY_BYTECODE);
        bytes32 hash = keccak256(abi.encodePacked(uint8(0xff), address(deployer), salt, bytecodeHash));
        return address(bytes20(hash << 96));
    }
}
