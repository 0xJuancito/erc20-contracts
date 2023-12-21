// This contract is not supposed to be used in production
// It's strictly for testing purpose

pragma solidity 0.6.6;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IMintableERC20} from "./IMintableERC20.sol";
import {NativeMetaTransaction} from "../../common/NativeMetaTransaction.sol";
import {ContextMixin} from "../../common/ContextMixin.sol";
import {AccessControlMixin} from "../../common/AccessControlMixin.sol";


contract Continuum is
    ERC20,
    AccessControlMixin,
    NativeMetaTransaction,
    ContextMixin,
    IMintableERC20
{
    bytes32 public constant PREDICATE_ROLE = keccak256("PREDICATE_ROLE");

    constructor()
      public
      ERC20("Continuum", "UM")
    {
        _setupContractId("Continuum");
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(PREDICATE_ROLE, _msgSender());
        _initializeEIP712("Continuum");
    }

  /**
    * @dev See {IMintableERC20-mint}.
    */
    function mint(address user, uint256 amount) external override only(PREDICATE_ROLE) {
      _mint(user, amount);
    }

    function _msgSender()
      internal
      override
      view
      returns (address payable sender)
    {
        return ContextMixin.msgSender();
    }
}
