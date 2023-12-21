// SPDX-License-Identifier: MPL-2.0
pragma solidity =0.8.16;

/**
 * @dev Interface of the PMG token standard
 */
interface IPias {
	// solhint-disable-next-line func-name-mixedcase
	function BURNER_ROLE() external returns (bytes32);

	// solhint-disable-next-line func-name-mixedcase
	function MINTER_ROLE() external returns (bytes32);

	/**
	 * @dev mint token
	 * @param _account minted address
	 * @param _amount token amount
	 */
	function mint(address _account, uint256 _amount) external;

	/**
	 * @dev burn token
	 * @param  _account buned address
	 * @param  _amount token amount
	 */
	function burn(address _account, uint256 _amount) external;
}
