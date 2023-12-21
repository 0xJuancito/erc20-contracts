// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.17;

import {ECDSAUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {CountersUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {SignatureChecker} from "@matterlabs/signature-checker/contracts/SignatureChecker.sol";

import {EIP712Upgradeable} from "../../cryptography/EIP712Upgradeable.sol";
import {IERC20PermitUpgradeable} from "./IERC20PermitUpgradeable.sol";
import {ISystemClock} from "../../../clock/ISystemClock.sol";
import {IDB} from "../../../db/IDB.sol";

abstract contract ERC20PermitUpgradeable is
  Initializable,
  ERC20Upgradeable,
  IERC20PermitUpgradeable,
  EIP712Upgradeable
{
  using CountersUpgradeable for CountersUpgradeable.Counter;

  // solhint-disable-next-line var-name-mixedcase
  bytes32 private _PERMIT_TYPEHASH;
  mapping(address => CountersUpgradeable.Counter) private _nonces;
  ISystemClock internal _systemClock;

  /**
   * @dev See {IERC20Permit-DOMAIN_SEPARATOR}.
   */
  // solhint-disable-next-line func-name-mixedcase
  function DOMAIN_SEPARATOR() external view override returns (bytes32) {
    return _domainSeparatorV4();
  }

  /**
   * @dev See {IERC20Permit-permit}.
   */
  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) public virtual override {
    require(
      block.timestamp <= deadline,
      "ERC20PermitUpgradeable: expired deadline"
    );

    bytes32 structHash = keccak256(
      abi.encode(
        _PERMIT_TYPEHASH,
        owner,
        spender,
        value,
        _useNonce(owner),
        deadline
      )
    );

    bytes32 hash = _hashTypedDataV4(structHash);

    address signer = ECDSAUpgradeable.recover(hash, v, r, s);
    require(signer == owner, "ERC20PermitUpgradeable: invalid signature");

    _approve(owner, spender, value);
  }

  /**
   * @dev See {IERC20Permit-permit}.
   */
  function permit2(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    bytes calldata sig
  ) public virtual override {
    require(
      _systemClock.time() <= deadline,
      "ERC20PermitUpgradeable: expired deadline"
    );

    bytes32 structHash = keccak256(
      abi.encode(
        _PERMIT_TYPEHASH,
        owner,
        spender,
        value,
        _useNonce(owner),
        deadline
      )
    );

    bytes32 hash = _hashTypedDataV4(structHash);

    require(
      SignatureChecker.isValidSignatureNow(owner, hash, sig),
      "ERC20PermitUpgradeable: invalid signature"
    );

    _approve(owner, spender, value);
  }

  /**
   * @dev See {IERC20Permit-nonces}.
   */
  function nonces(
    address owner
  ) public view virtual override returns (uint256) {
    return _nonces[owner].current();
  }

  /**
   * @dev Initializes the {EIP712} domain separator using the `name` parameter, and setting `version` to `"1"`.
   *
   * It's a good idea to use the same `name` that is defined as the ERC20 token name.
   */
  // solhint-disable-next-line func-name-mixedcase
  function __ERC20Permit_init(
    string memory name,
    IDB db
  ) internal onlyInitializing {
    __EIP712_init(name, "1");
    __ERC20Permit_init_unchained(name);

    _systemClock = ISystemClock(db.getAddress("SYSTEM_CLOCK"));
  }

  // solhint-disable-next-line func-name-mixedcase
  function __ERC20Permit_init_unchained(
    string memory
  ) internal onlyInitializing {
    _PERMIT_TYPEHASH = keccak256(
      "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
    );
  }

  /**
   * @dev "Consume a nonce": return the current value and increment.
   *
   * _Available since v4.1._
   */
  function _useNonce(address owner) internal virtual returns (uint256 current) {
    CountersUpgradeable.Counter storage nonce = _nonces[owner];
    current = nonce.current();
    nonce.increment();
  }

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  // solhint-disable-next-line ordering
  uint256[49] private __gap;
}
