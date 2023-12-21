// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

import "./ierc1363spender.sol";

contract Test_Spender is IERC1363Spender
    {
    address public           lastOwnerSeen                = address(0);
    uint256 public           lastValueSeen                = 0;
    bytes   public           lastDataSeen                 = bytes.concat();
    bytes4  private constant INTERFACE_ID_ERC1363_SPENDER = 0x7b04a2d0;

    function onApprovalReceived(address owner, uint256 value, bytes memory data) external override returns (bytes4)
        {
        lastOwnerSeen = owner;
        lastValueSeen = value;
        lastDataSeen = data;
        return INTERFACE_ID_ERC1363_SPENDER;
        }
    }
