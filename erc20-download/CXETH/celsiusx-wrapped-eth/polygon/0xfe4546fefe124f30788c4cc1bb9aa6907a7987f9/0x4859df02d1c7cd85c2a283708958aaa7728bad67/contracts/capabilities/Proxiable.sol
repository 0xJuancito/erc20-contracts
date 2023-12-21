// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Proxiable {
    // Code position in storage is keccak256("PROXIABLE") = "0xc5f16f0fcc639fa48a6947836d9850f504798523bf8c9a3a87d5876cf622bcf7"
    uint256 constant PROXIABLE_MEM_SLOT =
        0xc5f16f0fcc639fa48a6947836d9850f504798523bf8c9a3a87d5876cf622bcf7;

    event CodeAddressUpdated(address newAddress);

    function _updateCodeAddress(address newAddress) internal {
        require(
            bytes32(PROXIABLE_MEM_SLOT) ==
                Proxiable(newAddress).proxiableUUID(),
            "Not compatible"
        );
        assembly {
            // solium-disable-line
            sstore(PROXIABLE_MEM_SLOT, newAddress)
        }

        emit CodeAddressUpdated(newAddress);
    }

    function getLogicAddress() external view returns (address logicAddress) {
        assembly {
            // solium-disable-line
            logicAddress := sload(PROXIABLE_MEM_SLOT)
        }
    }

    function proxiableUUID() external pure returns (bytes32) {
        return bytes32(PROXIABLE_MEM_SLOT);
    }

    uint256[50] private __gap;
}
