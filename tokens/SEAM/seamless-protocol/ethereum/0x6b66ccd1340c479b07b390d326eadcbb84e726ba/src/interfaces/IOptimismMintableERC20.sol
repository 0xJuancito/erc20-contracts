// SPDX-License-Identifier: MIT
// https://github.com/ethereum-optimism/optimism/blob/de51656edb881d744681d9e1dbb1bfdefb4a8c83/packages/contracts-bedrock/src/universal/IOptimismMintableERC20.sol
pragma solidity ^0.8.0;

import {IERC165} from "openzeppelin-contracts/utils/introspection/IERC165.sol";

/// @title IOptimismMintableERC20
/// @notice This interface is available on the OptimismMintableERC20 contract.
///         We declare it as a separate interface so that it can be used in
///         custom implementations of OptimismMintableERC20.
interface IOptimismMintableERC20 is IERC165 {
    function remoteToken() external view returns (address);

    function bridge() external returns (address);

    function mint(address _to, uint256 _amount) external;

    function burn(address _from, uint256 _amount) external;
}
