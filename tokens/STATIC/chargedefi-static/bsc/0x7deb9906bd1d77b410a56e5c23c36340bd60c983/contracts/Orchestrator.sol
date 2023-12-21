// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;
import '@openzeppelin/contracts/access/AccessControlEnumerable.sol';
import './Interfaces/IRebaseListener.sol';

contract Orchestrator is AccessControlEnumerable {
	struct Transaction {
		bool enabled;
		address destination;
		bytes4 data;
	}

	// Transaction info that can be triggered after rebase
	Transaction[] public transactions;

	// Listeners than can be notified of a rebase
	IRebaseListener[] public listeners;

	/**
	 * @notice Adds a transaction that gets called for a downstream receiver of rebases
	 * @param destination Address of contract destination
	 * @param data Transaction data payload
	 */
	function addTransaction(address destination, string memory data)
		external
		onlyRole(DEFAULT_ADMIN_ROLE)
	{
		require(transactions.length <= 10, 'Too many transactions');
		Transaction memory tran = Transaction({
			enabled: true,
			destination: destination,
			data: bytes4(keccak256(bytes(data)))
		});
		transactions.push(tran);
	}

	/**
	 * @param index Index of transaction to remove.
	 *              Transaction ordering may have changed since adding.
	 */
	function removeTransaction(uint256 index)
		external
		onlyRole(DEFAULT_ADMIN_ROLE)
	{
		require(index < transactions.length, 'index out of range');
		if (index < transactions.length - 1) {
			transactions[index] = transactions[transactions.length - 1];
		}
		transactions.pop();
	}

	/**
	 * @param index Index of transaction. Transaction ordering may have changed since adding.
	 * @param enabled True for enabled, false for disabled.
	 */
	function setTransactionEnabled(uint256 index, bool enabled)
		external
		onlyRole(DEFAULT_ADMIN_ROLE)
	{
		require(
			index < transactions.length,
			'index must be in range of stored tx list'
		);
		transactions[index].enabled = enabled;
	}

	/**
	 * @return Number of transactions, both enabled and disabled, in transactions list.
	 */
	function transactionsSize() external view returns (uint256) {
		return transactions.length;
	}

	/**
	 * @notice Adds an address as IRebaseListener that gets called when a rebase happens
	 * @param listener Address of the listener contract
	 */
	function addListener(IRebaseListener listener)
		external
		onlyRole(DEFAULT_ADMIN_ROLE)
	{
		require(listeners.length <= 10, 'Too many listeners');

		for (uint256 i = 0; i < listeners.length; i++) {
			require(listeners[i] != listener, 'Listener exists');
		}
		listeners.push(listener);
	}

	/**
	 * @notice Removes an address as IRebaseListener that gets called when a rebase happens
	 * @param listener Address of the listener contract
	 */
	function removeListener(IRebaseListener listener)
		external
		onlyRole(DEFAULT_ADMIN_ROLE)
	{
		for (uint256 i = 0; i < listeners.length; i++) {
			if (listeners[i] == listener) {
				listeners[i] = listeners[listeners.length - 1];
				listeners.pop();
				return;
			}
		}

		revert('Listener not found');
	}

	/**
	 * @return Number of listeners, in the listener list
	 */
	function listenersSize() external view returns (uint256) {
		return listeners.length;
	}

	function _notifyRebase(
		uint256 prevRebaseSupply,
		uint256 currentRebaseSupply,
		uint256 prevTotalSupply,
		uint256 currentTotalSupply
	) internal {
		for (uint256 i = 0; i < transactions.length; i++) {
			Transaction storage t = transactions[i];
			if (t.enabled) {
				_externalCall(t.destination, t.data);
			}
		}

		for (uint256 i = 0; i < listeners.length; i++) {
			listeners[i].tokenRebased(
				address(this),
				prevRebaseSupply,
				currentRebaseSupply,
				prevTotalSupply,
				currentTotalSupply
			);
		}
	}

	/**
	 *  @dev wrapper to call the encoded transactions on downstream consumers.
	 *  @param destination Address of destination contract.
	 *  @param selector The selector of the function to be called.
	 */
	function _externalCall(address destination, bytes4 selector) private {
		(bool success, bytes memory data) = destination.call(
			abi.encodeWithSelector(selector)
		);
		require(
			success && (data.length == 0 || abi.decode(data, (bool))),
			'Orchestrator: Transaction Failed'
		);
	}
}
