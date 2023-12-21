// SPDX-License-Identifier: Apache-2.0

/**
 * Authors: Moonstream Engineering (engineering@moonstream.to)
 * GitHub: https://github.com/bugout-dev/dao
 *
 * Common storage structure and internal methods for Moonstream DAO ERC20 tokens.
 */

pragma solidity ^0.8.0;

library LibERC20 {
    bytes32 constant ERC20_STORAGE_POSITION =
        keccak256("moonstreamdao.eth.storage.erc20");

    struct ERC20Storage {
        string name;
        string symbol;
        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
        address controller;
        uint256 totalSupply;
    }

    function erc20Storage() internal pure returns (ERC20Storage storage es) {
        bytes32 position = ERC20_STORAGE_POSITION;
        assembly {
            es.slot := position
        }
    }

    event ControlTransferred(
        address indexed previousController,
        address indexed newController
    );

    function setController(address newController) internal {
        ERC20Storage storage es = erc20Storage();
        address previousController = es.controller;
        es.controller = newController;
        emit ControlTransferred(previousController, newController);
    }

    function enforceIsController() internal view {
        ERC20Storage storage es = erc20Storage();
        require(msg.sender == es.controller, "LibERC20: Must be controller");
    }
}
