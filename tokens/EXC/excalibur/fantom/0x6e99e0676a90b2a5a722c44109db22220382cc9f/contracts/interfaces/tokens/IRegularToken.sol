// SPDX-License-Identifier: MIT

pragma solidity =0.7.6;

import "./IERC20Mintable.sol";

interface IRegularToken is IERC20Mintable {
  function divTokenContractAddress() external view returns (address);

  function initializeDivTokenContractAddress(address _divToken) external;
}
