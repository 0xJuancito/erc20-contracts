// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title LSDai interface
 * @dev extention of ERC20 interface, with LSDai-specific events
 */
interface ILSDai is IERC20 {
  /**
   * @notice An executed shares transfer from `sender` to `recipient`.
   *
   * @dev emitted in pair with an ERC20-defined `Transfer` event.
   */
  event TransferShares(address indexed from, address indexed to, uint256 sharesValue);

  /**
   * @notice An executed `burnShares` request
   *
   * @dev Reports simultaneously burnt shares amount
   * and corresponding stETH amount.
   * The stETH amount is calculated twice: before and after the burning incurred rebase.
   *
   * @param account holder of the burnt shares
   * @param preRebaseTokenAmount amount of stETH the burnt shares corresponded to before the burn
   * @param postRebaseTokenAmount amount of stETH the burnt shares corresponded to after the burn
   * @param sharesAmount amount of burnt shares
   */
  event SharesBurnt(
    address indexed account, uint256 preRebaseTokenAmount, uint256 postRebaseTokenAmount, uint256 sharesAmount
  );

  /**
   * @dev emitted when the DAI deposit cap is set. set `setDepositCap` for more details.
   */
  event DepositCapSet(uint256 depositCap);

  /**
   * @dev emitted when the withdrawal fee is set. set `setWithdrawalFee` for more details.
   */
  event WithdrawalFeeSet(uint256 withdrawalFee);

  /**
   * @dev emitted when the interest fee is set. set `setInterestFee` for more details.
   */
  event InterestFeeSet(uint256 interestFee);

  /**
   * @dev emitted when the fee recipient is set. set `setFeeRecipient` for more details.
   */
  event FeeRecipientSet(address indexed recipient);

  /**
   * @notice The DAI deposit cap.
   * @dev can be changed by the owner of the contract.
   */
  function depositCap() external view returns (uint256);

  /**
   * @notice the fee recipient.
   * @dev can be changed by the owner of the contract.
   */
  function feeRecipient() external view returns (address);

  /**
   * @dev Updates the fee recipient. Only callable by the owner.
   * @param recipient The new fee recipient.
   */
  function setFeeRecipient(address recipient) external;

  /**
   * @notice sets the DAI deposit cap.
   * @dev can be changed by the owner of the contract.
   * @param cap the new DAI deposit cap.
   */
  function setDepositCap(uint256 cap) external;

  /**
   * @notice the interest fee percentage in basis points (1/100 of a percent)
   */
  function interestFee() external view returns (uint256);

  /**
   * @notice sets the interest fee percentage in basis points (1/100 of a percent)
   * @param fee the new interest fee percentage in basis points (1/100 of a percent)
   */
  function setInterestFee(uint256 fee) external;

  /**
   * @notice the withdrawal fee percentage in basis points (1/100 of a percent)
   */
  function withdrawalFee() external view returns (uint256);

  /**
   * @notice sets the withdrawal fee percentage in basis points (1/100 of a percent)
   * @param fee the new withdrawal fee percentage in basis points (1/100 of a percent)
   */
  function setWithdrawalFee(uint256 fee) external;

  /**
   * @dev initializes the contract.
   * @param _depositCap the DAI deposit cap.
   * @param _interestFee the interest fee percentage in basis points (1/100 of a percent)
   * @param _withdrawalFee the withdrawal fee percentage in basis points (1/100 of a percent)
   * @param _feeRecipient the address of the fee recipient
   */
  function initialize(uint256 _depositCap, uint256 _interestFee, uint256 _withdrawalFee, address _feeRecipient)
    external
    returns (bool);

  /**
   * @dev rebase the total pooled DAI, user balance and total supply of LSDAI.
   * Can only be called by anyone
   */
  function rebase() external;

  /**
   * @return the amount of tokens in existence.
   *
   * @dev Always equals to `_getTotalPooledDai()` since token amount
   * is pegged to the total amount of DAI controlled by the protocol.
   */
  function totalSupply() external view returns (uint256);

  /**
   * @return the amount of total LSDAI shares
   */
  function totalShares() external view returns (uint256);

  ////////////////////////////////////////
  // User functions //////////////////////
  ////////////////////////////////////////

  /// getters ///
  /**
   * @return the amount of shares owned by `_account`.
   */
  function sharesOf(address account) external view returns (uint256);

  /**
   * @notice Returns the amount of LSDai tokens owned by the `account`.
   * @dev Balances are dynamic and equal the `account`'s share in the amount of the
   * total DAI controlled by the protocol. See `sharesOf`.
   * @param account The address of the account to check the balance of.
   * @return The amount of LSDai tokens owned by the `account`.
   */
  function balanceOf(address account) external view returns (uint256);

  /**
   * @dev Deposit DAI and mint LSDAI.
   * @param to The address to mint LSDAI to.
   * @param daiAmount The amount of DAI to deposit.
   * @return amount of LSDAI minted.
   */
  function deposit(address to, uint256 daiAmount) external returns (uint256);

  /**
   * @dev Deposit DAI and mint LSDAI using ERC20 permit.
   * @param to The address to mint LSDAI to.
   * @param daiAmount The amount of DAI to deposit.
   * @param permitNonce The nonce of the permit signature.
   * @param permitExpiry The deadline timestamp, type(uint256).max for no deadline.
   * @param permitV The recovery byte of the signature.
   * @param permitR Half of the ECDSA signature pair.
   * @param permitS Half of the ECDSA signature pair.
   * @return amount amount of LSDAI minted.
   */
  function depositWithPermit(
    address to,
    uint256 daiAmount,
    uint256 permitNonce,
    uint256 permitExpiry,
    uint8 permitV,
    bytes32 permitR,
    bytes32 permitS
  ) external returns (uint256);

  /**
   * Withdraw DAI from the contract
   * @param daiAmount The amount of LSDAI to withdraw. wad is denominated in dai
   */
  function withdraw(uint256 daiAmount) external returns (bool);

  /**
   * @notice Returns the amount of LSDai shares that corresponds to `daiAmount` protocol-controlled DAI.
   * @param daiAmount The amount of protocol-controlled DAI.
   * @return The amount of LSDai shares that corresponds to `daiAmount` protocol-controlled DAI.
   */
  function getSharesByPooledDai(uint256 daiAmount) external view returns (uint256);

  /**
   * @notice Returns the amount of protocol-controlled DAI that corresponds to `sharesAmount` LSDai shares.
   * @param sharesAmount The amount of LSDai shares.
   * @return The amount of protocol-controlled DAI that corresponds to `sharesAmount` LSDai shares.
   */
  function getPooledDaiByShares(uint256 sharesAmount) external view returns (uint256);
}
