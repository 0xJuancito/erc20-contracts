//SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { EIP712 } from "./libraries/EIP712.sol";

abstract contract ApproveWithAuthorization is ERC20Upgradeable {

    struct ApprovalRequest {
        address owner;
        address spender;
        uint256 value;
        uint256 deadline;
        bytes32 nonce;
        uint256 currentApproval;
    }

    // keccak256("ApproveWithAuthorization(address owner,address spender,uint256 value,uint256 deadline,bytes32 nonce,uint256 currentApproval)")
    bytes32 public constant APPROVE_WITH_AUTHORIZATION_TYPEHASH = 0x7728b251b2f84612fd6271e82c54281223f0f808d4a779b17fc3e4aac5ccfb0b;

    bytes32 public DOMAIN_SEPARATOR;

    /**
     * @dev authorizer address => nonce => state (true = used / false = unused)
     */
    mapping(address => mapping(bytes32 => bool)) internal _authorizationStates;

    event AuthorizationUsed(address indexed authorizer, bytes32 indexed nonce);
    event AuthorizationCanceled(
        address indexed authorizer,
        bytes32 indexed nonce
    );

    string
        internal constant _INVALID_SIGNATURE_ERROR = "ApprovalRequest: invalid signature";
    string
        internal constant _AUTHORIZATION_USED_ERROR = "ApprovalRequest: authorization is already used";

    /**
     * @notice Returns the state of an authorization
     * @dev Nonces are randomly generated 32-byte data unique to the authorizer's
     * address
     * @param authorizer    Authorizer's address
     * @param nonce         Nonce of the authorization
     * @return True if the nonce is used
     */
    function authorizationState(address authorizer, bytes32 nonce)
        external
        view
        returns (bool)
    {
        return _authorizationStates[authorizer][nonce];
    }

    function approveWithAuthorization(
        ApprovalRequest memory req,
        bytes calldata sig
    ) external {

        require(block.timestamp < req.deadline, "ApprovalRequest: expired");
        require(!_authorizationStates[req.owner][req.nonce], _AUTHORIZATION_USED_ERROR);
        require(allowance(req.owner, req.spender) == req.currentApproval, "ApprovalRequest: Incorrect approval given");

        bytes memory data = abi.encodePacked(
            APPROVE_WITH_AUTHORIZATION_TYPEHASH,
            abi.encode(
                req.owner,
                req.spender,
                req.value,
                req.deadline,
                req.nonce,
                req.currentApproval
            )
        );

        require(
            EIP712.recover(DOMAIN_SEPARATOR, sig, data) == req.owner,
            _INVALID_SIGNATURE_ERROR
        );

        _authorizationStates[req.owner][req.nonce] = true;
        emit AuthorizationUsed(req.owner, req.nonce);

        _approve(req.owner, req.spender, req.value);
    }
}