// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.6.2;


interface ICitadelVesting {

    function updateInflationPct(uint value) external;
    function updateSnapshot(address account) external;
    function claimFor(address account) external returns (uint);

    function claimable(address account) external view returns (uint);

}
