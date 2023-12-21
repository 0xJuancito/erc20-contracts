// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Hamachi20Storage} from "../types/hamachi/Hamachi20Storage.sol";

import {LibAccessControlEnumerable} from "@lib-diamond/src/access/access-control/LibAccessControlEnumerable.sol";

import {LibHamachi} from "../libraries/LibHamachi.sol";
import {PERCENTAGE_DENOMINATOR} from "../types/hamachi/HamachiStorage.sol";
import {LibReward} from "../libraries/LibReward.sol";

import {EXCLUDED_FROM_MAX_WALLET_ROLE} from "../types/hamachi/HamachiRoles.sol";

error ExceedsMaxWallet(address recipient, uint256 amount);
error TransferFromZeroAddress();
error TransferToZeroAddress();
error TransferAmountExceedsBalance(uint256 amount, uint256 balance);
error MintToZeroAddress();
error BurnFromZeroAddress();
error BurnAmountExceedsBalance(uint256 amount, uint256 balance);
error InsufficientAllowance(uint256 amount, uint256 allowance);

error InvalidPermit(address recovered, address owner);
error PermitExpired(uint256 deadline);

library LibHamachi20 {
  /**
   * @dev Emitted when `value` tokens are moved from one account (`from`) to
   * another (`to`).
   *
   * Note that `value` may be zero.
   */
  event Transfer(address indexed from, address indexed to, uint256 value);

  /**
   * @dev Emitted when the allowance of a `spender` for an `owner` is set by
   * a call to {approve}. `value` is the new allowance.
   */
  event Approval(address indexed owner, address indexed spender, uint256 value);

  function _checkMaxWallet(address recipient, uint256 amount) internal view {
    if (
      !LibAccessControlEnumerable.hasRole(EXCLUDED_FROM_MAX_WALLET_ROLE, recipient) &&
      LibHamachi20.balanceOf(recipient) + amount > LibHamachi.DS().maxTokenPerWallet
    ) revert ExceedsMaxWallet(recipient, amount);
  }

  bytes32 internal constant ERC20_STORAGE_POSITION =
    keccak256("diamond.standard.erc20permit.storage");

  bytes32 internal constant PERMIT_TYPEHASH =
    keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
  bytes32 internal constant DOMAIN_SEPARATOR_TYPEHASH =
    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

  function DS() internal pure returns (Hamachi20Storage storage ds) {
    bytes32 position = ERC20_STORAGE_POSITION;
    assembly {
      ds.slot := position
    }
  }

  // This implements ERC-20.
  function totalSupply() internal view returns (uint256) {
    Hamachi20Storage storage ds = LibHamachi20.DS();
    return ds.totalSupply;
  }

  // This implements ERC-20.
  function balanceOf(address _owner) internal view returns (uint256) {
    Hamachi20Storage storage ds = LibHamachi20.DS();
    return ds.balances[_owner];
  }

  // This implements ERC-20.
  function transfer(address to, uint256 amount) internal returns (bool) {
    _transfer(msg.sender, to, amount);
    return true;
  }

  // This implements ERC-20.
  function allowance(address _owner, address _spender) internal view returns (uint256) {
    Hamachi20Storage storage ds = LibHamachi20.DS();
    return ds.allowances[_owner][_spender];
  }

  // This implements ERC-20.
  function approve(address _owner, address _spender, uint256 _value) internal returns (bool) {
    Hamachi20Storage storage ds = LibHamachi20.DS();
    ds.allowances[_owner][_spender] = _value;
    emit Approval(_owner, _spender, _value);
    return true;
  }

  // This implements ERC-20.
  function transferFrom(address from, address to, uint256 amount) internal returns (bool) {
    _spendAllowance(from, msg.sender, amount);
    _transfer(from, to, amount);
    return true;
  }

  // This implements ERC-20.
  function _transfer(address from, address to, uint256 amount) internal returns (bool) {
    _checkMaxWallet(to, amount);

    bool processingFees = LibHamachi.DS().processingFees;
    (uint256 taxFee, bool isSell) = LibHamachi.determineFee(from, to);
    if (taxFee > 0) {
      uint256 taxAmount = amount / (PERCENTAGE_DENOMINATOR + taxFee);
      taxAmount = amount - (taxAmount * PERCENTAGE_DENOMINATOR);

      if (taxAmount > 0) _transferInternal(from, address(this), taxAmount);

      uint256 sendAmount = amount - taxAmount;
      if (sendAmount > 0) _transferInternal(from, to, sendAmount);
    } else {
      _transferInternal(from, to, amount);
    }

    LibReward.setRewardBalance(from, balanceOf(from));
    LibReward.setRewardBalance(to, balanceOf(to));

    if (isSell && !processingFees && LibHamachi.DS().processRewards) LibReward.processRewards();
    return true;
  }

  function _transferInternal(address from, address to, uint256 amount) internal {
    Hamachi20Storage storage ds = LibHamachi20.DS();
    if (from == address(0)) revert TransferFromZeroAddress();
    if (to == address(0)) revert TransferToZeroAddress();

    uint256 fromBalance = ds.balances[from];
    if (fromBalance < amount) revert TransferAmountExceedsBalance(amount, fromBalance);
    unchecked {
      ds.balances[from] = fromBalance - amount;
      // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
      // decrementing then incrementing.
      ds.balances[to] += amount;
    }

    emit Transfer(from, to, amount);
  }

  function mint(address _account, uint256 _amount) internal {
    Hamachi20Storage storage ds = LibHamachi20.DS();
    if (_account == address(0)) revert MintToZeroAddress();
    unchecked {
      ds.totalSupply += _amount;
      ds.balances[_account] += _amount;
    }
    emit Transfer(address(0), _account, _amount);
  }

  function burn(address _account, uint256 _amount) internal {
    Hamachi20Storage storage ds = LibHamachi20.DS();
    if (_account == address(0)) revert BurnFromZeroAddress();
    uint256 accountBalance = ds.balances[_account];
    if (accountBalance < _amount) revert BurnAmountExceedsBalance(_amount, accountBalance);
    unchecked {
      ds.totalSupply -= _amount; // we already checked for balance above
      ds.balances[_account] = accountBalance - _amount;
    }
    emit Transfer(_account, address(0), _amount);
  }

  function increaseAllowance(
    address _owner,
    address _spender,
    uint256 _addedValue
  ) internal returns (bool) {
    Hamachi20Storage storage ds = LibHamachi20.DS();
    ds.allowances[_owner][_spender] += _addedValue;
    emit Approval(_owner, _spender, ds.allowances[_owner][_spender]);
    return true;
  }

  function decreaseAllowance(
    address _owner,
    address _spender,
    uint256 _subtractedValue
  ) internal returns (bool) {
    Hamachi20Storage storage ds = LibHamachi20.DS();
    uint256 oldValue = ds.allowances[_owner][_spender];
    if (_subtractedValue >= oldValue) {
      ds.allowances[_owner][_spender] = 0;
    } else {
      unchecked {
        ds.allowances[_owner][_spender] -= _subtractedValue;
      }
    }

    emit Approval(_owner, _spender, ds.allowances[_owner][_spender]);
    return true;
  }

  function _spendAllowance(address owner, address spender, uint256 amount) internal {
    uint256 currentAllowance = allowance(owner, spender);
    if (currentAllowance != type(uint256).max) {
      if (currentAllowance < amount) revert InsufficientAllowance(amount, currentAllowance);
      unchecked {
        approve(owner, spender, currentAllowance - amount);
      }
    }
  }

  /*//////////////////////////////////////////////////////////////
                            EIP-2612 LOGIC
  //////////////////////////////////////////////////////////////*/

  function computeDomainSeparator(string memory version) internal view returns (bytes32) {
    Hamachi20Storage storage ds = LibHamachi20.DS();
    return
      keccak256(
        abi.encode(
          DOMAIN_SEPARATOR_TYPEHASH,
          keccak256(bytes(ds.name)),
          keccak256(bytes(version)),
          block.chainid,
          address(this)
        )
      );
  }

  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s,
    bytes32 domainSeparator
  ) internal {
    Hamachi20Storage storage ds = LibHamachi20.DS();
    if (deadline < block.timestamp) revert PermitExpired(deadline);

    bytes32 structHash = keccak256(
      abi.encode(PERMIT_TYPEHASH, owner, spender, value, ds.nonces[owner]++, deadline)
    );

    bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    address recoveredAddress = ecrecover(digest, v, r, s);

    if (recoveredAddress == address(0) || recoveredAddress != owner)
      revert InvalidPermit(recoveredAddress, owner);

    approve(owner, spender, value);
  }

  function nonces(address owner) internal view returns (uint256) {
    Hamachi20Storage storage ds = LibHamachi20.DS();
    return ds.nonces[owner];
  }
}
