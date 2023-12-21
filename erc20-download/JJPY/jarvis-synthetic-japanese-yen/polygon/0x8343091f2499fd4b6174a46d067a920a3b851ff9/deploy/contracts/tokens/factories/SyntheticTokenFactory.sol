// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.4;

import {MintableBurnableIERC20} from '../interfaces/MintableBurnableIERC20.sol';
import {MintableBurnableTokenFactory} from './MintableBurnableTokenFactory.sol';
import {
  MintableBurnableSyntheticToken
} from '../MintableBurnableSyntheticToken.sol';

contract SynthereumSyntheticTokenFactory is MintableBurnableTokenFactory {
  //----------------------------------------
  // Constructor
  //----------------------------------------

  /**
   * @notice Constructs SynthereumSyntheticTokenFactory contract
   * @param _synthereumFinder Synthereum finder contract
   */
  constructor(address _synthereumFinder)
    MintableBurnableTokenFactory(_synthereumFinder)
  {}

  /**
   * @notice Create a new synthetic token and return it to the caller.
   * @dev The caller will become the only minter and burner and the new owner capable of assigning the roles.
   * @param tokenName used to describe the new token.
   * @param tokenSymbol short ticker abbreviation of the name. Ideally < 5 chars.
   * @param tokenDecimals used to define the precision used in the token's numerical representation.
   * @return newToken an instance of the newly created token
   */
  function createToken(
    string calldata tokenName,
    string calldata tokenSymbol,
    uint8 tokenDecimals
  )
    public
    override
    onlyDerivativeFactory
    nonReentrant()
    returns (MintableBurnableIERC20 newToken)
  {
    MintableBurnableSyntheticToken mintableToken =
      new MintableBurnableSyntheticToken(tokenName, tokenSymbol, tokenDecimals);
    newToken = MintableBurnableIERC20(address(mintableToken));
    _setAdminRole(newToken);
  }
}
