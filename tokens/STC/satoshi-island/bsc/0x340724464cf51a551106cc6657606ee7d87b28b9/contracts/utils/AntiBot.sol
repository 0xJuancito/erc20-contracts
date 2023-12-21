// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import '@openzeppelin/contracts/access/AccessControlEnumerable.sol';

contract AntiBot is AccessControlEnumerable {
    bytes32 public constant BOT_ROLE = keccak256('BOT_ROLE');
    bool public isAntibotEnabled = true;
    mapping(bytes => uint256) private transactions;

    event AntibotUpdated(bool isAntibotEnabled);

    modifier transactionThrottler(address from, address to) {
        if (isAntibotEnabled) {
            if (!hasRole(BOT_ROLE, from) && !hasRole(BOT_ROLE, to)) {
                require(
                    transactions[abi.encodePacked(from, to)] < block.number - 1 &&
                        transactions[abi.encodePacked(to, from)] < block.number - 1,
                    'Antibot: Transaction throttled'
                );
            }
            transactions[abi.encodePacked(from, to)] = block.number;
        }
        _;
    }

    function toggleAntibot() external onlyRole(DEFAULT_ADMIN_ROLE) {
        isAntibotEnabled = !isAntibotEnabled;
        emit AntibotUpdated(isAntibotEnabled);
    }
}
