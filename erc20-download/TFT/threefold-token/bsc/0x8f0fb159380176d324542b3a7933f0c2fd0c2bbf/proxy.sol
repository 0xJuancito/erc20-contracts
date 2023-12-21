pragma solidity >=0.7.0 <0.9.0;

import "./token_storage.sol";
import "./owned.sol";

// inherit from TokenStorage so we have the constructor, since the token variables need to be stored in the
// proxy's storage
contract Proxy is TokenStorage, Owned {
    fallback () external payable {
        // directly get the implementation contract address from the storage. This way we don't need to depend
        // on the upgradeable contract
        address _impl = getAddress(keccak256(abi.encode("implementation")));
        require(_impl != address(0), "The implementation address can't be the zero address");
        bytes memory data = msg.data;

        assembly {
            let result := delegatecall(gas(), _impl, add(data, 0x20), mload(data), 0, 0)
            let size := returndatasize()
            let ptr := mload(0x40)
            returndatacopy(ptr, 0, size)
            switch result
            case 0 { revert(ptr, size) }
            default { return(ptr, size) }
        }
    }

    constructor() {
        //set initial contract address, needs to be hardcoded
        // TODO: Set correct address
        address impl_addr = address(0xE160c705696F89277d06F26215A799bb068F61CB);
        require(impl_addr != address(0), "implementation address can not be the zero address");
        setAddress(keccak256(abi.encode("implementation")), impl_addr);
        setString(keccak256(abi.encode("version")),"0");

        // set initial owner
        setBool(keccak256(abi.encode("owner", msg.sender)), true);
    }
}