// SPDX-License-Identifier: BUSDL-1.1
pragma solidity 0.6.11;

import {
    Initializable as OZInitializable
} from "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";

contract Initializable is OZInitializable {
    /**
     * @dev Throws if called by any account other than the proxy admin.
     */
    modifier onlyProxyAdmin() {
        require(msg.sender == proxyAdmin(), "PROXY_ADMIN_ONLY");
        _;
    }

    /**
     * @dev Returns the proxy admin address using the slot specified in EIP-1967:
     *
     * 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
     *  = bytes32(uint256(keccak256('eip1967.proxy.admin')) - 1)
     */
    function proxyAdmin() public view returns (address adm) {
        bytes32 slot =
            0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            adm := sload(slot)
        }
    }
}
