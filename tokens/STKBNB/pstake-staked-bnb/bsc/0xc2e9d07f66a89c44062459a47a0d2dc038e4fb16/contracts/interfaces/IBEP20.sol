//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

/**
 * @title Interface representing the additional functionalities in a BEP20 token as compared to ERC777.
 * @dev See: https://github.com/bnb-chain/BEPs/blob/master/BEP20.md
 * Only the `getOwner()` function is an additional thing needed in the stkBNB implementation.
 * Rest of the BEP20 interface is already part of ERC777.
 */
interface IBEP20 {
    /**
     * @dev Returns the bep token owner.
     */
    function getOwner() external view returns (address);

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     * Emits the `OwnershipTransferred` event.
     *
     * Note that this is copied form the Ownable contract in Openzeppelin contracts.
     * We don't need rest of the functionalities from Ownable, including `renounceOwnership`
     * as we always want to have an owner for this contract.
     */
    function transferOwnership(address newOwner) external;

    /**
     * Emitted on `transferOwnership`.
     */
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
}
