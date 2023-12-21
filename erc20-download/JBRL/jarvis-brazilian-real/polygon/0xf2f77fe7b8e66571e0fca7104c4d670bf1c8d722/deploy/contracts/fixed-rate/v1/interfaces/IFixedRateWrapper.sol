// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {
  ISynthereumDeployment
} from '../../../common/interfaces/IDeployment.sol';
import {ITypology} from '../../../common/interfaces/ITypology.sol';

interface ISynthereumFixedRateWrapper is ITypology, ISynthereumDeployment {
  // Describe role structure
  struct Roles {
    address admin;
    address maintainer;
  }

  /** @notice This function is used to mint new fixed rate synthetic tokens by depositing peg collateral tokens
   * @notice The conversion is based on a fixed rate
   * @param _collateral The amount of peg collateral tokens to be deposited
   * @param _recipient The address of the recipient to receive the newly minted fixed rate synthetic tokens
   * @return amountTokens The amount of newly minted fixed rate synthetic tokens
   */
  function wrap(uint256 _collateral, address _recipient)
    external
    returns (uint256 amountTokens);

  /** @notice This function is used to burn fixed rate synthetic tokens and receive the underlying peg collateral tokens
   * @notice The conversion is based on a fixed rate
   * @param _tokenAmount The amount of fixed rate synthetic tokens to be burned
   * @param _recipient The address of the recipient to receive the underlying peg collateral tokens
   * @return amountCollateral The amount of peg collateral tokens withdrawn
   */
  function unwrap(uint256 _tokenAmount, address _recipient)
    external
    returns (uint256 amountCollateral);

  /** @notice A function that allows a maintainer to pause the execution of some functions in the contract
   * @notice This function suspends minting of new fixed rate synthetic tokens
   * @notice Pausing does not affect redeeming the peg collateral by burning the fixed rate synthetic tokens
   * @notice Pausing the contract is necessary in situations to prevent an issue with the smart contract or if the rate
   * between the fixed rate synthetic token and the peg collateral token changes
   */
  function pauseContract() external;

  /** @notice A function that allows a maintainer to resume the execution of all functions in the contract
   * @notice After the resume contract function is called minting of new fixed rate synthetic assets is open again
   */
  function resumeContract() external;

  /** @notice Check the conversion rate between peg-collateral and fixed-rate synthetic token
   * @return Coversion rate
   */
  function conversionRate() external view returns (uint256);

  /** @notice Amount of peg collateral stored in the contract
   * @return Total peg collateral deposited
   */
  function totalPegCollateral() external view returns (uint256);

  /** @notice Amount of synthetic tokens minted from the contract
   * @return Total synthetic tokens minted so far
   */
  function totalSyntheticTokensMinted() external view returns (uint256);

  /** @notice Check if wrap can be performed or not
   * @return True if minting is paused, otherwise false
   */
  function isPaused() external view returns (bool);
}
