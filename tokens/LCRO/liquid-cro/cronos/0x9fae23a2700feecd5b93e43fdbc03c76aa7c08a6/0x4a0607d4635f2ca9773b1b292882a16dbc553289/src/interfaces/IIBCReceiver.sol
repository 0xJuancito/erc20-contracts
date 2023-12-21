// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

interface IIBCReceiver {
    /**
     * Initiate a transfer to LiquidCro
     */
    function transfer() external;
}
