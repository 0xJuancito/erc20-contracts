// File: StableCoinToken/contracts/Common.sol


pragma solidity 0.8.21;

library ArrayOps {
  /**
   * @dev Function to delete elements from the array.
   * @param addressArray array of addresses.
   * @param elAddress address which to be removed.
   * @return Updated Array.
   */
  function deleteFromArray(
    address[] storage addressArray,
    address elAddress
  ) internal returns (address[] memory) {
    for (uint256 i = 0; i < addressArray.length; i++) {
      if (addressArray[i] == elAddress) {
        addressArray[i] = addressArray[addressArray.length - 1];
        addressArray.pop();
        break;
      }
    }
    return addressArray;
  }

  /**
   * @dev Function to Check if element is present in array.
   * @param addressArray array of addresses.
   * @param elAddress address which to be checked.
   * @return bool true if element is present else false.
   */
  function isElement(
    address[] memory addressArray,
    address elAddress
  ) internal pure returns (bool) {
    bool _isElement;
    for (uint256 i = 0; i < addressArray.length; i++) {
      if (addressArray[i] == elAddress) {
        _isElement = true;
        break;
      }
    }
    return _isElement;
  }
}

/**
 * @title Common
 * @notice Common variable declarations, Request Types, Sub Request Types, Structures, Events from both GovernanceToken and StableCoin.
 */
contract Common {
  /**
 * @notice Status of a request.
 * 0 - IN_PROGRESS, Request created
 * 1 - ACCEPTED, Approved by enough signatories
 * 2 - EXECUTED, Executed by request owner
 * 3 - CANCELLED, Cancelled by request owner
 */
  enum RequestStatus {
    IN_PROGRESS,
    ACCEPTED,
    EXECUTED,
    CANCELLED
  }

  /**
 * @notice Types of Requests.
 * 0 - TOKEN_SUPPLY_CONTROL (Burn,Mint)
 * 1 - TRANSACTION_CONTROL (Pause,Unpause)
 * 2 - SIGNATORY_CONTROL (Remove, Add)
 * 3 - THRESHOLD_CONTROL (Update)
 * 4 - WHITELIST_CONTROL (Remove, Add)
 *     note: Only on Governance Token
 */
  enum RequestType {
    TOKEN_SUPPLY_CONTROL,
    TRANSACTION_CONTROL,
    SIGNATORY_CONTROL,
    THRESHOLD_CONTROL,
    WHITELIST_CONTROL
  }

  /**
 * @notice Sub-Type of Token Supply Control
 * 0 - BURN
 * 1 - MINT
 */
  enum TokenSupplyControlRequestType {
    BURN,
    MINT
  }

  /**
 * @notice Sub-Type of Transaction Control
 * 0 - PAUSE
 * 1 - UNPAUSE
 */
  enum TransactionControlRequestType {
    PAUSE,
    UNPAUSE
  }

  /**
 * @notice Sub-Type of Signatory Control
 * 0 - REMOVE
 * 1 - ADD
 */
  enum SignatoryControlRequestType {
    REMOVE,
    ADD
  }

  /**
 * @notice Sub-Type of Threshold Control
 * 0 - UPDATE
 */
  enum ThresholdControlRequestType {
    UPDATE
  }

  /**
   * @notice Structure of a Token Supply control Request
   * id - ID of the Token Supply Control Request
   * subType - sub-Type of Token Supply control(MINT/BURN)
   * amount - Amount of token need to be minted or burned.
   * wallet - address of the wallet
   * owner - address of request owner
   * approvals - list of addresses who approved the request
   * status - status of request.
   */
  struct TokenSupplyControlRequests {
    uint256 id;
    TokenSupplyControlRequestType subType;
    uint256 amount;
    address wallet;
    address owner;
    address[] approvals;
    RequestStatus status;
  }

    /**
   * @notice Structure of a Transaction Control Request
   * id - ID of the Transaction Control Request
   * subType - sub-Type of Transaction control(PAUSE/UNPAUSE)
   * owner - address of request owner
   * approvals - list of addresses who approved the request
   * status - status of request.
   */
  struct TransactionControlRequests {
    uint256 id;
    TransactionControlRequestType subType;
    address owner;
    address[] approvals;
    RequestStatus status;
  }

  /**
   * @notice Structure of a Signatory Control Request
   * id - ID of the Signatory Control Request
   * subType - sub-Type of Transaction control(ADD/REMOVE)
   * wallets - list of addresses needs to be added or removed
   * owner - address of request owner
   * approvals - list of addresses who approved the request
   * status - status of request.
   */
  struct SignatoryControlRequests {
    uint256 id;
    SignatoryControlRequestType subType;
    address[] wallets;
    address owner;
    address[] approvals;
    RequestStatus status;
  }

  /**
   * @notice Structure of a Threshold Control Request
   * id - ID of the Threshold Control Request
   * reqType - request type for which threshold need to update
   * thresholds - list of threshold values
   * owner - address of request owner
   * approvals - list of addresses who approved the request
   * status - status of request.
   */
  struct ThresholdControlRequests {
    uint256 id;
    RequestType reqType;
    ThresholdControlRequestType subType;
    uint256[] thresholds;
    address owner;
    address[] approvals;
    RequestStatus status;
  }

  /// mapping to check if address is a signatory or not.
  mapping(address => bool) internal isSignatory;
  /// List of all signatories.
  address[] internal signatoryList;

  /// mapping for the count of request types.
  mapping(RequestType => uint256) internal requestTypeCount;

  /// mapping for the threshold count for token supply.
  mapping(TokenSupplyControlRequestType => uint256) internal tokenSupplyControlThresholds;
  /// mapping of all the token supply request.
  mapping(uint256 => TokenSupplyControlRequests) internal tokenSupplyControlRequests;

  /// mapping for the threshold count for Transaction Control.
  mapping(TransactionControlRequestType => uint256) internal transactionControlThresholds;
  /// mapping of all the Transaction control request.
  mapping(uint256 => TransactionControlRequests) internal transactionControlRequests;

  /// mapping for the threshold count for Signatory Control.
  mapping(SignatoryControlRequestType => uint256) internal signatoryControlThresholds;
  /// mapping of all the Signatory control request.
  mapping(uint256 => SignatoryControlRequests) internal signatoryControlRequests;

  /// mapping for the threshold count for Threshold Control.
  mapping(ThresholdControlRequestType => uint256) internal thresholdControlThresholds;
  /// mapping of all the Threshold control request.
  mapping(uint256 => ThresholdControlRequests) internal thresholdControlRequests;

  /// event when a request is created.
  event RequestCreated(
    RequestType indexed reqType,
    uint256 indexed subType,
    address indexed ownerAddress,
    uint256 reqId
  );
  /// event when a request is cancelled.
  event RequestCancelled(RequestType indexed reqType, uint256 indexed reqId);
  /// event when a request is updated.
  event RequestUpdated(RequestType indexed reqType, uint256 indexed reqId);
  /// event when a request is approved.
  event RequestApproval(
    RequestType indexed reqType,
    uint256 indexed reqId,
    address indexed signatoryAddress,
    bool isApproved
  );

  /// event when a signatory is updated.
  event SignatoriesUpdated(
    SignatoryControlRequestType indexed reqType,
    uint256 indexed reqId,
    address[] signatoryAddress
  );
  /// event when a Threshold is updated.
  event ThresholdUpdated(
    RequestType indexed reqType,
    uint256 indexed reqId,
    uint256[] newThresholds
  );

  /**
   * @dev modifier function to allow only to the signatories.
   */
  modifier onlySignatory() {
    require(isSignatory[msg.sender], 'UNAUTHORIZED!');
    _;
  }

  /**
   * @dev setting the count of all request types.
   */
  function _setRequestTypeCount() internal {
    requestTypeCount[RequestType.TOKEN_SUPPLY_CONTROL] = 2;
    requestTypeCount[RequestType.TRANSACTION_CONTROL] = 2;
    requestTypeCount[RequestType.SIGNATORY_CONTROL] = 2;
    requestTypeCount[RequestType.THRESHOLD_CONTROL] = 1;
    requestTypeCount[RequestType.WHITELIST_CONTROL] = 2;
  }

  /**
   * @dev to check that a request can be cancelled or not.
   * @param owner owner of the request.
   * @param status status of the request.
   */
  function _isCancellable(address owner, RequestStatus status) internal view {
    require(owner != address(0), 'INVALID_REQUEST!');
    require(owner == msg.sender, 'UNAUTHORIZED!');
    require(status == RequestStatus.IN_PROGRESS || status == RequestStatus.ACCEPTED, 'NOT_ACTIVE!');
  }

  /**
   * @dev to check that a request can be approved or not.
   * @param owner owner of the request.
   * @param status status of the request.
   */
  function _isApprovable(address owner, RequestStatus status) internal pure {
    require(owner != address(0), 'INVALID_REQUEST!');
    require(status == RequestStatus.IN_PROGRESS || status == RequestStatus.ACCEPTED, 'NOT_ACTIVE!');
  }

  /**
   * @dev to check that a request can be executed or not.
   * @param owner owner of the request.
   * @param status status of the request.
   */
  function _isExecutable(address owner, RequestStatus status) internal view {
    require(owner != address(0), 'INVALID_REQUEST!');
    require(owner == msg.sender, 'UNAUTHORIZED!');
    require(status == RequestStatus.ACCEPTED, 'NOT_APPROVED!');
  }
}

// File: StableCoinToken/@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol


// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly
                /// @solidity memory-safe-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// File: StableCoinToken/@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol


// OpenZeppelin Contracts (last updated v4.7.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;


/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts. Equivalent to `reinitializer(1)`.
     */
    modifier initializer() {
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1) || (!AddressUpgradeable.isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
        _initialized = 1;
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * `initializer` is equivalent to `reinitializer(1)`, so a reinitializer may be used after the original
     * initialization step. This is essential to configure modules that are added through upgrades and that require
     * initialization.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     */
    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized < type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }
}

// File: StableCoinToken/@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol


// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;


/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuardUpgradeable is Initializable {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    function __ReentrancyGuard_init() internal onlyInitializing {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal onlyInitializing {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// File: StableCoinToken/@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol


// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;


/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// File: StableCoinToken/@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol


// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;



/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal onlyInitializing {
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal onlyInitializing {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// File: StableCoinToken/@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol


// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

pragma solidity ^0.8.0;



/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract PausableUpgradeable is Initializable, ContextUpgradeable {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    function __Pausable_init() internal onlyInitializing {
        __Pausable_init_unchained();
    }

    function __Pausable_init_unchained() internal onlyInitializing {
        _paused = false;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable: paused");
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// File: StableCoinToken/@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol


// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
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

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

// File: StableCoinToken/@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol


// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;


/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20MetadataUpgradeable is IERC20Upgradeable {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// File: StableCoinToken/@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol


// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;





/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20Upgradeable is Initializable, ContextUpgradeable, IERC20Upgradeable, IERC20MetadataUpgradeable {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    function __ERC20_init(string memory name_, string memory symbol_) internal onlyInitializing {
        __ERC20_init_unchained(name_, symbol_);
    }

    function __ERC20_init_unchained(string memory name_, string memory symbol_) internal onlyInitializing {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[45] private __gap;
}

// File: StableCoinToken/@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol


// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/ERC20Pausable.sol)

pragma solidity ^0.8.0;




/**
 * @dev ERC20 token with pausable token transfers, minting and burning.
 *
 * Useful for scenarios such as preventing trades until the end of an evaluation
 * period, or having an emergency switch for freezing all token transfers in the
 * event of a large bug.
 */
abstract contract ERC20PausableUpgradeable is Initializable, ERC20Upgradeable, PausableUpgradeable {
    function __ERC20Pausable_init() internal onlyInitializing {
        __Pausable_init_unchained();
    }

    function __ERC20Pausable_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {ERC20-_beforeTokenTransfer}.
     *
     * Requirements:
     *
     * - the contract must not be paused.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        require(!paused(), "ERC20Pausable: token transfer while paused");
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// File: StableCoinToken/contracts/StableCoin.sol

/**
 * SPDX-License-Identifier: MIT
 * @author Accubits
 * @title Stable Coin
 */

pragma solidity 0.8.21;







/**
 * @title Stable Coin.
 */

contract StableCoin is
  Initializable,
  ERC20Upgradeable,
  ERC20PausableUpgradeable,
  OwnableUpgradeable,
  Common,
  ReentrancyGuardUpgradeable
{
  /// to store decimal.
  uint8 internal _decimals;
  /// Address of Governance Token.
  address internal _governanceTokenAddress;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /**
   * @dev   To initialize Contract.
   * @param name_             ERC20 Token Name.
   * @param symbol_           ERC20 Token Symbol.
   * @param decimals_         ERC20 decimal allows.
   * @param governanceToken_  Address of Governance Token
   * @param owner_            Address of Contract owner
   */
  function initialize(
    string memory name_,
    string memory symbol_,
    uint8 decimals_,
    address governanceToken_,
    address owner_
  ) public initializer {
    __ERC20_init(name_, symbol_);
    __ERC20Pausable_init();
    __Ownable_init();

    isSignatory[owner_] = true;
    signatoryList.push(owner_);

    _decimals = decimals_;
    _governanceTokenAddress = governanceToken_;
    _setRequestTypeCount();
    _setDefaultThresholds();

    _transferOwnership(owner_);
  }

  /**
   * @dev Function to set dafault Thresholds for all operations.
   */
  function _setDefaultThresholds() private {
    tokenSupplyControlThresholds[TokenSupplyControlRequestType.BURN] = 1;
    tokenSupplyControlThresholds[TokenSupplyControlRequestType.MINT] = 1;
    transactionControlThresholds[TransactionControlRequestType.PAUSE] = 1;
    transactionControlThresholds[TransactionControlRequestType.UNPAUSE] = 1;
    signatoryControlThresholds[SignatoryControlRequestType.ADD] = 1;
    signatoryControlThresholds[SignatoryControlRequestType.REMOVE] = 1;
    thresholdControlThresholds[ThresholdControlRequestType.UPDATE] = 1;
  }

  /**
   * @dev    override function to modify the decimal support for the Token.
   * @return uint8 number of decimals allowed
   */
  function decimals() public view virtual override returns (uint8) {
    return _decimals;
  }

  /**
   * @dev    Fetching list of all the Signatories.
   * @return address[] Array containing all signatories.
   */
  function getSignatoryList() external view returns (address[] memory) {
    return signatoryList;
  }

  /**
   * @dev    To get the Threshold value for specified Request Type.
   * @param  reqType_ Type of operation.
   * @return uint256[] array containing Threshold count for the Request Type.
   */
  function getThresholds(RequestType reqType_) external view returns (uint256[] memory) {
    uint256[] memory thresholds = new uint256[](requestTypeCount[reqType_]);
    for (uint256 i; i < requestTypeCount[reqType_]; i++) {
      if (reqType_ == RequestType.TOKEN_SUPPLY_CONTROL) {
        thresholds[i] = tokenSupplyControlThresholds[TokenSupplyControlRequestType(i)];
      } else if (reqType_ == RequestType.TRANSACTION_CONTROL) {
        thresholds[i] = transactionControlThresholds[TransactionControlRequestType(i)];
      } else if (reqType_ == RequestType.SIGNATORY_CONTROL) {
        thresholds[i] = signatoryControlThresholds[SignatoryControlRequestType(i)];
      } else {
        thresholds[i] = thresholdControlThresholds[ThresholdControlRequestType(i)];
      }
    }
    return thresholds;
  }

  /**
   * @dev    To see the Requested Object for Token Supply.
   * @param  id_ ID of the request.
   * @return Structure of Token Supply Request of given ID.
   */
  function getTokenSupplyControlRequest(
    uint256 id_
  ) external view returns (TokenSupplyControlRequests memory) {
    require(tokenSupplyControlRequests[id_].owner != address(0), 'INVALID_REQUEST!');
    return tokenSupplyControlRequests[id_];
  }

  /**
   * @dev    To see the Requested Object for Transaction Control.
   * @param  id_ ID of the request.
   * @return Structure of Transaction Control Request of given ID.
   */
  function getTransactionControlRequest(
    uint256 id_
  ) external view returns (TransactionControlRequests memory) {
    require(transactionControlRequests[id_].owner != address(0), 'INVALID_REQUEST!');
    return transactionControlRequests[id_];
  }

  /**
   * @dev    To see the Requested Object for Signatory Control.
   * @param  id_ ID of the request.
   * @return Structure of Signatory Control Request of given ID.
   */
  function getSignatoryControlRequest(
    uint256 id_
  ) external view returns (SignatoryControlRequests memory) {
    require(signatoryControlRequests[id_].owner != address(0), 'INVALID_REQUEST!');
    return signatoryControlRequests[id_];
  }

  /**
   * @dev    To see the Requested Object for Threshold Control.
   * @param  id_ ID of the request.
   * @return Structure of Threshold Control Request of given ID.
   */
  function getThresholdControlRequest(
    uint256 id_
  ) external view returns (ThresholdControlRequests memory) {
    require(thresholdControlRequests[id_].owner != address(0), 'INVALID_REQUEST!');
    return thresholdControlRequests[id_];
  }

  /**
   * @dev   To create a Token Supply Control Request.
   * @param reqSubType_ Sub Type of the request (Mint/Burn).
   * @param id_         ID for the newly created Request.
   * @param amount_     Ammount of Tokens for minting or burning.
   * @param to_         Address of receiver.
   */
  function createTokenSupplyControlRequest(
    TokenSupplyControlRequestType reqSubType_,
    uint256 id_,
    uint256 amount_,
    address to_
  ) external onlySignatory {
    require(tokenSupplyControlRequests[id_].owner == address(0), 'INVALID_REQUEST!');

    tokenSupplyControlRequests[id_].id = id_;
    tokenSupplyControlRequests[id_].subType = reqSubType_;
    tokenSupplyControlRequests[id_].amount = amount_;
    tokenSupplyControlRequests[id_].wallet = to_;
    tokenSupplyControlRequests[id_].owner = msg.sender;
    tokenSupplyControlRequests[id_].status = RequestStatus.IN_PROGRESS;

    emit RequestCreated(RequestType.TOKEN_SUPPLY_CONTROL, uint256(reqSubType_), msg.sender, id_);
  }

  /**
   * @dev   To update a Token Supply Control Request.
   * @param id_         ID of the request needs to be updated.
   * @param amount_     new Ammount of Tokens for minting or burning.
   * @param to_         new Address of receiver.
   */
  function updateTokenSupplyControlRequest(
    uint256 id_,
    uint256 amount_,
    address to_
  ) external onlySignatory {
    require(tokenSupplyControlRequests[id_].owner != address(0), 'INVALID_REQUEST!');
    require(tokenSupplyControlRequests[id_].owner == msg.sender, 'UNAUTHORIZED!');
    require(tokenSupplyControlRequests[id_].status == RequestStatus.IN_PROGRESS, 'NOT_ACTIVE!');

    tokenSupplyControlRequests[id_].amount = amount_;
    tokenSupplyControlRequests[id_].wallet = to_;
    tokenSupplyControlRequests[id_].approvals = new address[](0);

    emit RequestUpdated(RequestType.TOKEN_SUPPLY_CONTROL, id_);
  }

  /**
   * @dev   To create a Transaction Control Request.
   * @param reqSubType_ Sub Type of the request (Pause/Unpause).
   * @param id_         ID for the newly created Request.
   */
  function createTransactionControlRequest(
    TransactionControlRequestType reqSubType_,
    uint256 id_
  ) external onlySignatory {
    require(transactionControlRequests[id_].owner == address(0), 'INVALID_REQUEST!');

    transactionControlRequests[id_].id = id_;
    transactionControlRequests[id_].subType = reqSubType_;
    transactionControlRequests[id_].owner = msg.sender;
    transactionControlRequests[id_].status = RequestStatus.IN_PROGRESS;

    emit RequestCreated(RequestType.TRANSACTION_CONTROL, uint256(reqSubType_), msg.sender, id_);
  }

  /**
   * @dev   Request To create a Signatories.
   * @param reqSubType_ Sub Type of the request (ADD/REMOVE).
   * @param id_         ID for the newly created Request.
   * @param users_      list of signatories to add or remove.
   */
  function createSignatoryControlRequest(
    SignatoryControlRequestType reqSubType_,
    uint256 id_,
    address[] memory users_
  ) external onlySignatory {
    require(signatoryControlRequests[id_].owner == address(0), 'INVALID_REQUEST!');

    signatoryControlRequests[id_].id = id_;
    signatoryControlRequests[id_].subType = reqSubType_;
    signatoryControlRequests[id_].wallets = users_;
    signatoryControlRequests[id_].owner = msg.sender;
    signatoryControlRequests[id_].status = RequestStatus.IN_PROGRESS;

    emit RequestCreated(RequestType.SIGNATORY_CONTROL, uint256(reqSubType_), msg.sender, id_);
  }

  /**
   * @dev   To update a Signatory Control Request.
   * @param id_    ID of the request needs to be updated.
   * @param users_ new list of signatories.
   */
  function updateSignatoryControlRequest(
    uint256 id_,
    address[] memory users_
  ) external onlySignatory {
    require(signatoryControlRequests[id_].owner != address(0), 'INVALID_REQUEST!');
    require(signatoryControlRequests[id_].owner == msg.sender, 'UNAUTHORIZED!');
    require(signatoryControlRequests[id_].status == RequestStatus.IN_PROGRESS, 'NOT_ACTIVE!');

    signatoryControlRequests[id_].wallets = users_;
    signatoryControlRequests[id_].approvals = new address[](0);
    emit RequestUpdated(RequestType.SIGNATORY_CONTROL, id_);
  }

  /**
   * @dev   Request To create Threshold Control.
   * @param reqType_    Request Type for which thresholds need to change.
   * @param id_         ID for the newly created Request.
   * @param thresholds_ list of thresholds for the request.
   */
  function createThresholdControlRequest(
    RequestType reqType_,
    uint256 id_,
    uint256[] memory thresholds_
  ) external onlySignatory {
    require(thresholdControlRequests[id_].owner == address(0), 'INVALID_REQUEST!');
    require(thresholds_.length == requestTypeCount[reqType_], 'INVALID_THRESHOLD_COUNTS!');
    for(uint256 i;i < thresholds_.length;i++){
      require(thresholds_[i] > 0, 'INVALID_THRESHOLD!');
    }

    thresholdControlRequests[id_].id = id_;
    thresholdControlRequests[id_].reqType = reqType_;
    thresholdControlRequests[id_].subType = ThresholdControlRequestType.UPDATE;
    thresholdControlRequests[id_].thresholds = thresholds_;
    thresholdControlRequests[id_].owner = msg.sender;
    thresholdControlRequests[id_].status = RequestStatus.IN_PROGRESS;

    emit RequestCreated(RequestType.THRESHOLD_CONTROL, uint256(ThresholdControlRequestType.UPDATE), msg.sender, id_);
  }

  /**
   * @dev   To update a Threshold Control Request.
   * @param id_         ID of the request needs to be updated.
   * @param thresholds_ new list of Thresholds for the request Type.
   */
  function updateThresholdControlRequest(
    uint256 id_,
    uint256[] memory thresholds_
  ) external onlySignatory {
    require(thresholdControlRequests[id_].owner != address(0), 'INVALID_REQUEST!');
    require(thresholdControlRequests[id_].owner == msg.sender, 'UNAUTHORIZED!');
    require(thresholdControlRequests[id_].status == RequestStatus.IN_PROGRESS, 'NOT_ACTIVE!');
    require(
      thresholds_.length == requestTypeCount[thresholdControlRequests[id_].reqType],
      'INVALID_THRESHOLD_COUNTS!'
    );
    for(uint256 i;i < thresholds_.length;i++){
      require(thresholds_[i] > 0, 'INVALID_THRESHOLD!');
    }
    thresholdControlRequests[id_].thresholds = thresholds_;
    thresholdControlRequests[id_].approvals = new address[](0);

    emit RequestUpdated(RequestType.THRESHOLD_CONTROL, id_);
  }

  /**
   * @dev To vote for a request of any type.
   * @param reqType_  Request Type of operations.
   * @param id_       ID of the request, which was made previously.
   * @param approval_ true for approval, false for rejection.
   */
  function vote(
    RequestType reqType_,
    uint256 id_,
    bool approval_
  ) external onlySignatory nonReentrant {
    if (reqType_ == RequestType.TOKEN_SUPPLY_CONTROL) {
      _isApprovable(tokenSupplyControlRequests[id_].owner, tokenSupplyControlRequests[id_].status);

      bool isApproved = ArrayOps.isElement(tokenSupplyControlRequests[id_].approvals, msg.sender);
      if (approval_) {
        require(!isApproved, 'APPROVED!');
        tokenSupplyControlRequests[id_].approvals.push(msg.sender);
      } else {
        require(isApproved, 'NOT_APPROVED!');
        address[] memory updatedApprovals = ArrayOps.deleteFromArray(
          tokenSupplyControlRequests[id_].approvals,
          msg.sender
        );
        tokenSupplyControlRequests[id_].approvals = updatedApprovals;
      }

      tokenSupplyControlRequests[id_].status = tokenSupplyControlRequests[id_].approvals.length >=
        tokenSupplyControlThresholds[tokenSupplyControlRequests[id_].subType]
        ? RequestStatus.ACCEPTED
        : RequestStatus.IN_PROGRESS;
    } else if (reqType_ == RequestType.TRANSACTION_CONTROL) {
      _isApprovable(transactionControlRequests[id_].owner, transactionControlRequests[id_].status);

      bool isApproved = ArrayOps.isElement(transactionControlRequests[id_].approvals, msg.sender);
      if (approval_) {
        require(!isApproved, 'APPROVED!');
        transactionControlRequests[id_].approvals.push(msg.sender);
      } else {
        require(isApproved, 'NOT_APPROVED!');
        address[] memory updatedApprovals = ArrayOps.deleteFromArray(
          transactionControlRequests[id_].approvals,
          msg.sender
        );
        transactionControlRequests[id_].approvals = updatedApprovals;
      }

      transactionControlRequests[id_].status = transactionControlRequests[id_].approvals.length >=
        transactionControlThresholds[transactionControlRequests[id_].subType]
        ? RequestStatus.ACCEPTED
        : RequestStatus.IN_PROGRESS;
    } else if (reqType_ == RequestType.SIGNATORY_CONTROL) {
      _isApprovable(signatoryControlRequests[id_].owner, signatoryControlRequests[id_].status);

      bool isApproved = ArrayOps.isElement(signatoryControlRequests[id_].approvals, msg.sender);
      if (approval_) {
        require(!isApproved, 'APPROVED!');
        signatoryControlRequests[id_].approvals.push(msg.sender);
      } else {
        require(isApproved, 'NOT_APPROVED!');
        signatoryControlRequests[id_].approvals = ArrayOps.deleteFromArray(
          signatoryControlRequests[id_].approvals,
          msg.sender
        );
      }

      signatoryControlRequests[id_].status = signatoryControlRequests[id_].approvals.length >=
        signatoryControlThresholds[signatoryControlRequests[id_].subType]
        ? RequestStatus.ACCEPTED
        : RequestStatus.IN_PROGRESS;
    } else if (reqType_ == RequestType.THRESHOLD_CONTROL) {
      _isApprovable(thresholdControlRequests[id_].owner, thresholdControlRequests[id_].status);

      bool isApproved = ArrayOps.isElement(thresholdControlRequests[id_].approvals, msg.sender);
      if (approval_) {
        require(!isApproved, 'APPROVED!');
        thresholdControlRequests[id_].approvals.push(msg.sender);
      } else {
        require(isApproved, 'NOT_APPROVED!');
        thresholdControlRequests[id_].approvals = ArrayOps.deleteFromArray(
          thresholdControlRequests[id_].approvals,
          msg.sender
        );
      }

      thresholdControlRequests[id_].status = thresholdControlRequests[id_].approvals.length >=
        thresholdControlThresholds[thresholdControlRequests[id_].subType]
        ? RequestStatus.ACCEPTED
        : RequestStatus.IN_PROGRESS;
    } else {
      revert('UNKNOWN_REQUEST!');
    }

    emit RequestApproval(reqType_, id_, msg.sender, approval_);
  }

  /**
   * @dev To execute the operation, if thresholds are valid then it will execute else revert.
   * @param reqType_ Type of Request which needs to be executed.
   * @param id_      ID of the request.
   */
  function execute(RequestType reqType_, uint256 id_) external {
    if (reqType_ == RequestType.TOKEN_SUPPLY_CONTROL) {
      _isExecutable(tokenSupplyControlRequests[id_].owner, tokenSupplyControlRequests[id_].status);

      if (TokenSupplyControlRequestType.MINT == tokenSupplyControlRequests[id_].subType) {
        _mint(tokenSupplyControlRequests[id_].wallet, tokenSupplyControlRequests[id_].amount);
      } else {
        if (tokenSupplyControlRequests[id_].wallet == tokenSupplyControlRequests[id_].owner) {
          _burn(tokenSupplyControlRequests[id_].owner, tokenSupplyControlRequests[id_].amount);
        } else if (tokenSupplyControlRequests[id_].wallet == address(this)) {
          _burn(address(this), tokenSupplyControlRequests[id_].amount);
        } else {
          require(
            allowance(
              tokenSupplyControlRequests[id_].wallet,
              tokenSupplyControlRequests[id_].owner
            ) >= tokenSupplyControlRequests[id_].amount,
            'INSUFFICIENT_ALLOWANCE!'
          );
          _spendAllowance(
            tokenSupplyControlRequests[id_].wallet,
            tokenSupplyControlRequests[id_].owner,
            tokenSupplyControlRequests[id_].amount
          );
          _burn(tokenSupplyControlRequests[id_].wallet, tokenSupplyControlRequests[id_].amount);
        }
      }

      tokenSupplyControlRequests[id_].status = RequestStatus.EXECUTED;
    } else if (reqType_ == RequestType.TRANSACTION_CONTROL) {
      _isExecutable(transactionControlRequests[id_].owner, transactionControlRequests[id_].status);

      if (TransactionControlRequestType.PAUSE == transactionControlRequests[id_].subType) {
        _pause();
      } else {
        _unpause();
      }

      transactionControlRequests[id_].status = RequestStatus.EXECUTED;
    } else if (reqType_ == RequestType.SIGNATORY_CONTROL) {
      _isExecutable(signatoryControlRequests[id_].owner, signatoryControlRequests[id_].status);

      for (uint256 i; i < signatoryControlRequests[id_].wallets.length; i++) {
        if (SignatoryControlRequestType.ADD == signatoryControlRequests[id_].subType) {
          require(!isSignatory[signatoryControlRequests[id_].wallets[i]], 'EXISTING!');
          isSignatory[signatoryControlRequests[id_].wallets[i]] = true;
          signatoryList.push(signatoryControlRequests[id_].wallets[i]);
        } else {
          require(signatoryList.length > 1, 'LAST_SIGNATORY!');
          require(isSignatory[signatoryControlRequests[id_].wallets[i]], 'UNKNOWN!');
          isSignatory[signatoryControlRequests[id_].wallets[i]] = false;
          signatoryList = ArrayOps.deleteFromArray(
            signatoryList,
            signatoryControlRequests[id_].wallets[i]
          );
        }
      }

      signatoryControlRequests[id_].status = RequestStatus.EXECUTED;
      emit SignatoriesUpdated(
        signatoryControlRequests[id_].subType,
        id_,
        signatoryControlRequests[id_].wallets
      );
    } else if (reqType_ == RequestType.THRESHOLD_CONTROL) {
      _isExecutable(thresholdControlRequests[id_].owner, thresholdControlRequests[id_].status);

      for (uint256 i; i < requestTypeCount[thresholdControlRequests[id_].reqType]; i++) {
        if (thresholdControlRequests[id_].reqType == RequestType.TOKEN_SUPPLY_CONTROL) {
          tokenSupplyControlThresholds[TokenSupplyControlRequestType(i)] = thresholdControlRequests[
            id_
          ].thresholds[i];
        } else if (thresholdControlRequests[id_].reqType == RequestType.TRANSACTION_CONTROL) {
          transactionControlThresholds[TransactionControlRequestType(i)] = thresholdControlRequests[
            id_
          ].thresholds[i];
        } else if (thresholdControlRequests[id_].reqType == RequestType.SIGNATORY_CONTROL) {
          signatoryControlThresholds[SignatoryControlRequestType(i)] = thresholdControlRequests[id_]
            .thresholds[i];
        } else {
          thresholdControlThresholds[ThresholdControlRequestType(i)] = thresholdControlRequests[id_]
            .thresholds[i];
        }
      }

      thresholdControlRequests[id_].status = RequestStatus.EXECUTED;
      emit ThresholdUpdated(thresholdControlRequests[id_].reqType, id_, thresholdControlRequests[id_].thresholds);
    } else {
      revert('UNKNOWN_REQUEST!');
    }
  }

  /**
   * @dev To cancel a request which is made previously.
   * @param reqType_ Request Type of operation.
   * @param id_      ID of the pending request.
   */
  function cancelRequest(RequestType reqType_, uint256 id_) external onlySignatory nonReentrant {
    if (reqType_ == RequestType.TOKEN_SUPPLY_CONTROL) {
      _isCancellable(tokenSupplyControlRequests[id_].owner, tokenSupplyControlRequests[id_].status);
      tokenSupplyControlRequests[id_].status = RequestStatus.CANCELLED;
    } else if (reqType_ == RequestType.TRANSACTION_CONTROL) {
      _isCancellable(transactionControlRequests[id_].owner, transactionControlRequests[id_].status);
      transactionControlRequests[id_].status = RequestStatus.CANCELLED;
    } else if (reqType_ == RequestType.SIGNATORY_CONTROL) {
      _isCancellable(signatoryControlRequests[id_].owner, signatoryControlRequests[id_].status);
      signatoryControlRequests[id_].status = RequestStatus.CANCELLED;
    } else if (reqType_ == RequestType.THRESHOLD_CONTROL) {
      _isCancellable(thresholdControlRequests[id_].owner, thresholdControlRequests[id_].status);
      thresholdControlRequests[id_].status = RequestStatus.CANCELLED;
    } else {
      revert('UNKNOWN_REQUEST!');
    }
    emit RequestCancelled(reqType_, id_);
  }

  /**
   * @dev To mint the Token by swaping.
   * @param user_   address of receiver.
   * @param amount_ Amount of token to be minted.
   */
  function swap(address user_, uint256 amount_) external nonReentrant {
    require(msg.sender == _governanceTokenAddress, 'UNAUTHORIZED!');
    _mint(user_, amount_);
  }

  /**
   * @dev     Overriding inherited hook
   * @param   from   Address from which token amount is transfer.
   * @param   to     Address to which token amount is received.
   * @param   amount Token amount to be transfer.
   */
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal override(ERC20Upgradeable,ERC20PausableUpgradeable) whenNotPaused {
    super._beforeTokenTransfer(from, to, amount);
  }
}