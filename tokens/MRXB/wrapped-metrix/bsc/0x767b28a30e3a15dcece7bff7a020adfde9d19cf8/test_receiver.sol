// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

import "./ierc1363receiver.sol";

contract Test_Receiver is IERC1363Receiver
    {
    address public           lastOperatorSeen              = address(0);
    address public           lastFromSeen                  = address(0);
    uint256 public           lastValueSeen                 = 0;
    bytes   public           lastDataSeen                  = bytes.concat();
    bytes4  private constant INTERFACE_ID_ERC1363_RECEIVER = 0x88a7ca5c;

    function onTransferReceived(address operator, address from, uint256 value, bytes memory data) external override returns (bytes4)
        {
        lastOperatorSeen = operator;
        lastFromSeen = from;
        lastValueSeen = value;
        lastDataSeen = data;
        return INTERFACE_ID_ERC1363_RECEIVER;
        }
    }
