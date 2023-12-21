// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IMYRC {
    error FromRestrictedAddress(address addr);
    error ToRestrictedAddress(address addr);
    error NoZeroAddress();
    error SameRestrictionFlag(address addr, bool flag);
    error ERC20RescueFailed(address addr);
    error ETHRescueFailed();
    error InvalidArrayLength();

    event Restricted(address indexed addr, bool flag);

    function mint(address to, uint256 amount) external;

    function restrictAddress(address addr, bool flag) external;

    function rescueToken(address tokenAddress, address to) external;

    function rescueEth(address payable to) external;
}
