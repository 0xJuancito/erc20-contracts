// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/utils/Context.sol";

import "erc-payable-token/contracts/payment/ERC1363Payable.sol";

/**
 * @title ERC1363Payable
 * @author Vittorio Minacori (https://github.com/vittominacori)
 * @dev Implementation proposal of a contract that wants to accept ERC1363 payments
 */
// solhint-disable no-unused-vars
contract MockERC1363PayableContract is ERC1363Payable {
    uint256 public foo;

    /**
     * @param acceptedToken_ Address of the token being accepted
     */
    constructor(IERC1363 acceptedToken_) ERC1363Payable(acceptedToken_) {}

    function setFoo(uint256 num) public {
        console.log("foo");
        foo = num;
    }

    function _transferReceived(
        address _operator,
        address _sender,
        uint256 _amount,
        bytes memory data
    ) internal override {
        bytes4 fnSig;
        bytes memory rest;

        // The following assembly is necessary to decode a `bytes memory` array.
        // Get function signature in call embedded in data:
        //      fnSig <- data[0:3]
        //      rest <- data[4:]

        // solhint-disable-next-line no-inline-assembly
        assembly {
            // load the first bytes of data (after 32 byte size offset)
            fnSig := mload(add(data, 32))
            // subtract size of fn sig from size, and store new size (overwriting fn sig in data)
            mstore(add(data, 4), sub(mload(data), 4))
            // load the new bytes array created with line above as the rest
            rest := add(data, 4)
        }

        // decode params from data
        uint256 newFoo = abi.decode(rest, (uint256));

        // set foo
        foo = newFoo;
    }
}
