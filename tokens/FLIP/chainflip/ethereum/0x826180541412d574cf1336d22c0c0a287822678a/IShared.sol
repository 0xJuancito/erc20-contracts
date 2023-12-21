// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "IERC20.sol";

/**
 * @title    Shared interface
 * @notice   Holds structs needed by other interfaces
 */
interface IShared {
    /**
     * @dev  SchnorrSECP256K1 requires that each key has a public key part (x coordinate),
     *       a parity for the y coordinate (0 if the y ordinate of the public key is even, 1
     *       if it's odd)
     */
    struct Key {
        uint256 pubKeyX;
        uint8 pubKeyYParity;
    }

    /**
     * @dev  Contains a signature and the nonce used to create it. Also the recovered address
     *       to check that the signature is valid
     */
    struct SigData {
        uint256 sig;
        uint256 nonce;
        address kTimesGAddress;
    }

    /**
     * @param token The address of the token to be transferred
     * @param recipient The address of the recipient of the transfer
     * @param amount    The amount to transfer, in wei (uint)
     */
    struct TransferParams {
        address token;
        address payable recipient;
        uint256 amount;
    }

    /**
     * @param swapID    The unique identifier for this swap (bytes32), used for create2
     * @param token     The token to be transferred
     */
    struct DeployFetchParams {
        bytes32 swapID;
        address token;
    }

    /**
     * @param fetchContract   The address of the deployed Deposit contract
     * @param token     The token to be transferred
     */
    struct FetchParams {
        address payable fetchContract;
        address token;
    }
}
