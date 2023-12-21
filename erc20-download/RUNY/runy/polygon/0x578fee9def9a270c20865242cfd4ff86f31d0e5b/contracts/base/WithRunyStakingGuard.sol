// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title WithRunyStakingGuard
 */
abstract contract WithRunyStakingGuard is Ownable {
    mapping(address => bool) public runyStakingOperators;
    event RunyStakingOperatorSet(
        address indexed operator,
        bool indexed isOperator
    );

    function setRunyStakingOperator(
        address _operator,
        bool _isOperator
    ) public onlyOwner {
        runyStakingOperators[_operator] = _isOperator;
        emit RunyStakingOperatorSet(_operator, _isOperator);
    }

    function isRunyStakingOperator(
        address _operator
    ) public view returns (bool) {
        return runyStakingOperators[_operator];
    }

    modifier onlyRunyStakingOperator() {
        require(isRunyStakingOperator(_msgSender()), "permission_denied");
        _;
    }
}
