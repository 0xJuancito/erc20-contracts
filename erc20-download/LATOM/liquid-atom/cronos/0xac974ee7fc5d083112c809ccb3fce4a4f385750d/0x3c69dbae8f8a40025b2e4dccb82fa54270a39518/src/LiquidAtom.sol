// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "./LiquidToken.sol";

contract LiquidAtom is LiquidToken {
    function bridge(uint256 amount) external override onlyRole(ROLE_BOT) {
        require(amount <= totalTokenToBridge, "amount must be smaller than totalTokenToBridge");
        require(bytes(bridgeDestination).length > 0, "EMPTY_DESTINATION");

        totalTokenToBridge -= amount;
        token.send_to_ibc(bridgeDestination, amount);

        emit Bridge(amount);
    }
}
