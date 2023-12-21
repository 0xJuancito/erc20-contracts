// SPDX-License-Identifier: gpl-3.0

pragma solidity 0.7.5;

import './bases/BaseTokenUpgradeable.sol';

import '@openzeppelin/contracts-upgradeable/proxy/Initializable.sol';

contract EthixToken is Initializable, BaseTokenUpgradeable {
    function initialize() public initializer {
        // TODO: Set the initial address for minting
        __BaseTokenUpgradeable_init(
            msg.sender,
            100000000 * 10**18,
            'Ethix',
            'ETHIX',
            'Ethix'
        );
    }
}
