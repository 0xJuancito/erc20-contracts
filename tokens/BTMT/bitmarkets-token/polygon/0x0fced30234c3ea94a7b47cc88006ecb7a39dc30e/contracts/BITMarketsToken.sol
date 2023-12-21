// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.14;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Snapshot} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import {ERC20StrategicWalletRestrictions} from "./token/ERC20StrategicWalletRestrictions.sol";
import {ERC20Fees} from "./token/ERC20Fees.sol";

import {IBITMarketsToken} from "./utils/IBITMarketsToken.sol";

/**
 * @dev Constructor
 * @param initialSupply The total number of tokens to mint without the decimals
 * @param finalSupply The minimum amount of token supply without the decimals
 * @param allocationsWalletTokens The total amount of tokens to be minted in the team allocation wallet
 * @param crowdsalesWalletTokens The total amount of tokens to be minted in the crowdsales-specific wallet
 * @param companyRate The percentage of every transfer that goes back to company wallet (0-1000)
 * @param esgFundRate The percentage of every transfer that ends up in the ESG fund (0-1000)
 * @param burnRate The percentage of every transfer that gets burned (0-1000)
 * @param allocationsWallet The address of the team allocation etc. token holder wallet
 * @param crowdsalesWallet The address of the crowdsales token holder wallet
 * @param companyRewardsWallet The address that receives the transfer fees for the company
 * @param esgFundWallet The address that handles the ESG fund from gathered transfer fees
 */
struct BTMTArgs {
  uint32 initialSupply;
  uint32 finalSupply;
  uint32 allocationsWalletTokens;
  uint32 crowdsalesWalletTokens;
  uint32 maxCompanyWalletTransfer;
  uint16 companyRate;
  uint16 esgFundRate;
  uint16 burnRate;
  address allocationsWallet;
  address crowdsalesWallet;
  address companyRewardsWallet;
  address esgFundWallet;
  address feelessAdminWallet;
  address companyRestrictionWhitelistWallet;
}

/// @custom:security-contact security@bitmarkets.com
contract BITMarketsToken is
  IBITMarketsToken,
  ERC20,
  ERC20Snapshot,
  ERC20Burnable,
  ERC20StrategicWalletRestrictions,
  ERC20Fees,
  AccessControl
{
  bytes32 public constant SNAPSHOT_ROLE = keccak256("SNAPSHOT_ROLE");

  constructor(
    BTMTArgs memory args
  )
    ERC20("BITMarketsToken", "BTMT")
    ERC20StrategicWalletRestrictions(
      args.companyRestrictionWhitelistWallet,
      args.allocationsWallet,
      args.crowdsalesWallet,
      args.maxCompanyWalletTransfer,
      1
    )
    ERC20Fees(
      args.finalSupply,
      args.companyRate,
      args.esgFundRate,
      args.burnRate,
      msg.sender,
      args.companyRewardsWallet,
      args.esgFundWallet,
      args.feelessAdminWallet
    )
  {
    require(
      args.allocationsWalletTokens + args.crowdsalesWalletTokens < args.initialSupply,
      "Invalid initial funds"
    );
    require(args.initialSupply >= args.finalSupply, "Invalid final supply");
    require(args.finalSupply > 0, "Less than zero final supply");

    // Company wallet
    _mint(msg.sender, args.initialSupply * 10 ** decimals());
    // TODO check if needed
    _approve(msg.sender, args.allocationsWallet, args.allocationsWalletTokens * 10 ** decimals());
    _approve(msg.sender, args.crowdsalesWallet, args.crowdsalesWalletTokens * 10 ** decimals());

    // Setup roles
    _setupRole(SNAPSHOT_ROLE, msg.sender);
  }

  /**
   * @dev Takes snapshot of state and can return to it
   */
  function snapshot() public virtual override onlyRole(SNAPSHOT_ROLE) {
    _snapshot();
  }

  /**
   * @dev Overridable function
   */
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal override(ERC20, ERC20Snapshot, ERC20StrategicWalletRestrictions, ERC20Fees) {
    super._beforeTokenTransfer(from, to, amount);
  }

  /**
   * @dev Overridable function
   */
  function _afterTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal override(ERC20, ERC20Fees) {
    super._afterTokenTransfer(from, to, amount);
  }
}
