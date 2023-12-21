// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.9.0;

struct NonRebaseInfo {
    address pool;
    uint256 amount;
    uint256[10] __gap;
}

interface IPayoutManager {

    function payoutDone(address _token, NonRebaseInfo [] memory nonRebaseInfo) external;

}
