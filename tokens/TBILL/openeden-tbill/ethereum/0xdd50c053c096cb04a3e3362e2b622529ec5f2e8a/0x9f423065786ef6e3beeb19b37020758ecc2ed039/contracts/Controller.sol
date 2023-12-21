// SPDX-License-Identifier: MIT
pragma solidity =0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./OEPausable.sol";

/**
 * @title Controller
 * @dev The Controller contract manages pausing and unpausing of deposit and withdrawal operations.
 * It also defines roles for administrators and operators.
 */
contract Controller is OEPausable, AccessControl {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /**
     * @dev Emitted when both deposit and withdrawal operations are paused.
     */
    event PauseAll();

    /**
     * @dev Modifier to check if the caller has admin or operator role.
     */
    modifier onlyAdminOrOperator() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()) ||
                hasRole(OPERATOR_ROLE, _msgSender()),
            "permission denied"
        );
        _;
    }

    /**
     * @dev Constructor to initialize the Controller contract.
     * @param _operator The address of the operator role.
     * @param _admin The address of the admin role.
     */
    constructor(address _operator, address _admin) {
        require(_admin != address(0), "invalid admin address");
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(OPERATOR_ROLE, _operator);
    }

    /**
     * @dev Pause deposit operations. Can only be called by an admin or operator.
     */
    function pauseDeposit() external onlyAdminOrOperator {
        _pauseDeposit();
    }

    /**
     * @dev Pause withdrawal operations. Can only be called by an admin or operator.
     */
    function pauseWithdraw() external onlyAdminOrOperator {
        _pauseWithdraw();
    }

    /**
     * @dev Unpause deposit operations. Can only be called by an admin or operator.
     */
    function unpauseDeposit() external onlyAdminOrOperator {
        _unpauseDeposit();
    }

    /**
     * @dev Unpause withdrawal operations. Can only be called by an admin or operator.
     */
    function unpauseWithdraw() external onlyAdminOrOperator {
        _unpauseWithdraw();
    }

    /**
     * @dev Pause both deposit and withdrawal operations. Can only be called by an admin or operator.
     * Emits a PauseAll event.
     */
    function pauseAll() external onlyAdminOrOperator {
        _pauseDeposit();
        _pauseWithdraw();
        emit PauseAll();
    }

    /**
     * @dev Check if withdrawal operations are paused. Can be called by any user.
     * Throws an error if withdrawal operations are paused.
     */
    function requireNotPausedWithdraw() external view {
        _requireNotPausedWithdraw();
    }

    /**
     * @dev Check if deposit operations are paused. Can be called by any user.
     * Throws an error if deposit operations are paused.
     */
    function requireNotPausedDeposit() external view {
        _requireNotPausedDeposit();
    }
}
