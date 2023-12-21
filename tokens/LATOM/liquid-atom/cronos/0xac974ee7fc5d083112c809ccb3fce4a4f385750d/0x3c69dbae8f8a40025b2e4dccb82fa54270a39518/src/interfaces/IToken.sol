// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @notice token on cronos side, it should be either a CRC20 or CRC21 token
 * @dev    When Veno supports liquid staking for tokens using CRC21, other methods eg. send_to_chain will be added here
 *         and the implementation: LiquidAtom or LiquidCro should choose the appropriate method to call
 */
interface IToken is IERC20 {
    // Ref: https://github.com/crypto-org-chain/cronos-public-contracts/blob/master/CRC20/ModuleCRC20.sol
    // send an "amount" of the contract token to recipient through IBC
    function send_to_ibc(string memory recipient, uint amount) external;

    function decimals() external view returns (uint8);
}
