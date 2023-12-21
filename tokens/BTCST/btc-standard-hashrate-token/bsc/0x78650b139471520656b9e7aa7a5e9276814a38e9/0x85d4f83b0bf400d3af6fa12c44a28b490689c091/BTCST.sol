/**
 *Submitted for verification at BscScan.com on 2021-01-05
*/

// File: contracts/3rdParty/@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol



pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMathUpgradeable {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

// File: contracts/3rdParty/@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol



pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 */
library EnumerableSetUpgradeable {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;

        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping (bytes32 => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) { // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            // When the value to delete is the last one, the swap operation is unnecessary. However, since this occurs
            // so rarely, we still do the swap anyway to avoid the gas cost of adding an 'if' statement.

            bytes32 lastvalue = set._values[lastIndex];

            // Move the last value to the index where the value to delete is
            set._values[toDeleteIndex] = lastvalue;
            // Update the index for the moved value
            set._indexes[lastvalue] = toDeleteIndex + 1; // All indexes are 1-based

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        require(set._values.length > index, "EnumerableSet: index out of bounds");
        return set._values[index];
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(value)));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(value)));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(value)));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint256(_at(set._inner, index)));
    }


    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }
}

// File: contracts/3rdParty/@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol



pragma solidity >=0.6.2 <0.8.0;

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
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
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

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
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
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
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

// File: contracts/3rdParty/@openzeppelin/contracts-upgradeable/proxy/Initializable.sol



// solhint-disable-next-line compiler-version
pragma solidity >=0.4.24 <0.8.0;


/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 * 
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {UpgradeableProxy-constructor}.
 * 
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 */
abstract contract Initializable {

    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        require(_initializing || _isConstructor() || !_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }

    /// @dev Returns true if and only if the function is running in the constructor
    function _isConstructor() private view returns (bool) {
        // extcodesize checks the size of the code stored in an address, and
        // address returns the current address. Since the code is still not
        // deployed when running a constructor, any checks on its code size will
        // yield zero, making it an effective way to detect if a contract is
        // under construction or not.
        address self = address(this);
        uint256 cs;
        // solhint-disable-next-line no-inline-assembly
        assembly { cs := extcodesize(self) }
        return cs == 0;
    }
}

// File: contracts/3rdParty/@openzeppelin/contracts-upgradeable/GSN/ContextUpgradeable.sol



pragma solidity >=0.6.0 <0.8.0;


/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal initializer {
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal initializer {
    }
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
    uint256[50] private __gap;
}

// File: contracts/3rdParty/@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol



pragma solidity >=0.6.0 <0.8.0;





/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it.
 */
abstract contract AccessControlUpgradeable is Initializable, ContextUpgradeable {
    function __AccessControl_init() internal initializer {
        __Context_init_unchained();
        __AccessControl_init_unchained();
    }

    function __AccessControl_init_unchained() internal initializer {
    }
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using AddressUpgradeable for address;

    struct RoleData {
        EnumerableSetUpgradeable.AddressSet members;
        bytes32 adminRole;
    }

    mapping (bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role].members.contains(account);
    }

    /**
     * @dev Returns the number of accounts that have `role`. Can be used
     * together with {getRoleMember} to enumerate all bearers of a role.
     */
    function getRoleMemberCount(bytes32 role) public view returns (uint256) {
        return _roles[role].members.length();
    }

    /**
     * @dev Returns one of the accounts that have `role`. `index` must be a
     * value between 0 and {getRoleMemberCount}, non-inclusive.
     *
     * Role bearers are not sorted in any particular way, and their ordering may
     * change at any point.
     *
     * WARNING: When using {getRoleMember} and {getRoleMemberCount}, make sure
     * you perform all queries on the same block. See the following
     * https://forum.openzeppelin.com/t/iterating-over-elements-on-enumerableset-in-openzeppelin-contracts/2296[forum post]
     * for more information.
     */
    function getRoleMember(bytes32 role, uint256 index) public view returns (address) {
        return _roles[role].members.at(index);
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) public virtual {
        require(hasRole(_roles[role].adminRole, _msgSender()), "AccessControl: sender must be an admin to grant");

        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) public virtual {
        require(hasRole(_roles[role].adminRole, _msgSender()), "AccessControl: sender must be an admin to revoke");

        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) public virtual {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        emit RoleAdminChanged(role, _roles[role].adminRole, adminRole);
        _roles[role].adminRole = adminRole;
    }

    function _grantRole(bytes32 role, address account) private {
        if (_roles[role].members.add(account)) {
            emit RoleGranted(role, account, _msgSender());
        }
    }

    function _revokeRole(bytes32 role, address account) private {
        if (_roles[role].members.remove(account)) {
            emit RoleRevoked(role, account, _msgSender());
        }
    }
    uint256[49] private __gap;
}

// File: contracts/3rdParty/@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol



pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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
}

// File: contracts/3rdParty/@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol



pragma solidity >=0.6.0 <0.8.0;





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
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
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
contract ERC20Upgradeable is Initializable, ContextUpgradeable, IERC20Upgradeable {
    using SafeMathUpgradeable for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18.
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    function __ERC20_init(string memory name_, string memory symbol_) internal initializer {
        __Context_init_unchained();
        __ERC20_init_unchained(name_, symbol_);
    }

    function __ERC20_init_unchained(string memory name_, string memory symbol_) internal initializer {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
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
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
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
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
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
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function _transferDirect(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
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

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
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
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Sets {decimals} to a value other than the default one of 18.
     *
     * WARNING: This function should only be called from the constructor. Most
     * applications that interact with token contracts will not expect
     * {decimals} to ever change, and may work incorrectly if it does.
     */
    function _setupDecimals(uint8 decimals_) internal {
        _decimals = decimals_;
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
    uint256[44] private __gap;
}

// File: contracts/3rdParty/@openzeppelin/contracts-upgradeable/token/ERC20/ERC20BurnableUpgradeable.sol



pragma solidity >=0.6.0 <0.8.0;




/**
 * @dev Extension of {ERC20} that allows token holders to destroy both their own
 * tokens and those that they have an allowance for, in a way that can be
 * recognized off-chain (via event analysis).
 */
abstract contract ERC20BurnableUpgradeable is Initializable, ContextUpgradeable, ERC20Upgradeable {
    function __ERC20Burnable_init() internal initializer {
        __Context_init_unchained();
        __ERC20Burnable_init_unchained();
    }

    function __ERC20Burnable_init_unchained() internal initializer {
    }
    using SafeMathUpgradeable for uint256;

    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, deducting from the caller's
     * allowance.
     *
     * See {ERC20-_burn} and {ERC20-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `amount`.
     */
    function burnFrom(address account, uint256 amount) public virtual {
        uint256 decreasedAllowance = allowance(account, _msgSender()).sub(amount, "ERC20: burn amount exceeds allowance");

        _approve(account, _msgSender(), decreasedAllowance);
        _burn(account, amount);
    }
    uint256[50] private __gap;
}

// File: contracts/3rdParty/@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol



pragma solidity >=0.6.0 <0.8.0;



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
    function __Pausable_init() internal initializer {
        __Context_init_unchained();
        __Pausable_init_unchained();
    }

    function __Pausable_init_unchained() internal initializer {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!_paused, "Pausable: paused");
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
        require(_paused, "Pausable: not paused");
        _;
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
    uint256[49] private __gap;
}

// File: contracts/3rdParty/@openzeppelin/contracts-upgradeable/token/ERC20/ERC20PausableUpgradeable.sol



pragma solidity >=0.6.0 <0.8.0;




/**
 * @dev ERC20 token with pausable token transfers, minting and burning.
 *
 * Useful for scenarios such as preventing trades until the end of an evaluation
 * period, or having an emergency switch for freezing all token transfers in the
 * event of a large bug.
 */
abstract contract ERC20PausableUpgradeable is Initializable, ERC20Upgradeable, PausableUpgradeable {
    function __ERC20Pausable_init() internal initializer {
        __Context_init_unchained();
        __Pausable_init_unchained();
        __ERC20Pausable_init_unchained();
    }

    function __ERC20Pausable_init_unchained() internal initializer {
    }
    /**
     * @dev See {ERC20-_beforeTokenTransfer}.
     *
     * Requirements:
     *
     * - the contract must not be paused.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        require(!paused(), "ERC20Pausable: token transfer while paused");
    }
    uint256[50] private __gap;
}

// File: contracts/3rdParty/@openzeppelin/contracts-upgradeable/presets/ERC20PresetMinterPauserUpgradeable.sol



pragma solidity >=0.6.0 <0.8.0;







/**
 * @dev {ERC20} token, including:
 *
 *  - ability for holders to burn (destroy) their tokens
 *  - a minter role that allows for token minting (creation)
 *  - a pauser role that allows to stop all token transfers
 *
 * This contract uses {AccessControl} to lock permissioned functions using the
 * different roles - head to its documentation for details.
 *
 * The account that deploys the contract will be granted the minter and pauser
 * roles, as well as the default admin role, which will let it grant both minter
 * and pauser roles to other accounts.
 */
contract ERC20PresetMinterPauserUpgradeable is Initializable, ContextUpgradeable, AccessControlUpgradeable, ERC20BurnableUpgradeable, ERC20PausableUpgradeable {
    function initialize(string memory name, string memory symbol) public virtual initializer {
        __ERC20PresetMinterPauser_init(name, symbol);
    }
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /**
     * @dev Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE` and `PAUSER_ROLE` to the
     * account that deploys the contract.
     *
     * See {ERC20-constructor}.
     */
    function __ERC20PresetMinterPauser_init(string memory name, string memory symbol) internal initializer {
        __Context_init_unchained();
        __AccessControl_init_unchained();
        __ERC20_init_unchained(name, symbol);
        __ERC20Burnable_init_unchained();
        __Pausable_init_unchained();
        __ERC20Pausable_init_unchained();
        __ERC20PresetMinterPauser_init_unchained(name, symbol);
    }

    function __ERC20PresetMinterPauser_init_unchained(string memory name, string memory symbol) internal initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
    }

    /**
     * @dev Creates `amount` new tokens for `to`.
     *
     * See {ERC20-_mint}.
     *
     * Requirements:
     *
     * - the caller must have the `MINTER_ROLE`.
     */
    function mint(address to, uint256 amount) public virtual {
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC20PresetMinterPauser: must have minter role to mint");
        _mint(to, amount);
    }

    /**
     * @dev Pauses all token transfers.
     *
     * See {ERC20Pausable} and {Pausable-_pause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function pause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "ERC20PresetMinterPauser: must have pauser role to pause");
        _pause();
    }

    /**
     * @dev Unpauses all token transfers.
     *
     * See {ERC20Pausable} and {Pausable-_unpause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function unpause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "ERC20PresetMinterPauser: must have pauser role to unpause");
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        super._beforeTokenTransfer(from, to, amount);
    }
    uint256[50] private __gap;
}

// File: contracts/3rdParty/@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol



pragma solidity >=0.6.0 <0.8.0;


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

    function __ReentrancyGuard_init() internal initializer {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal initializer {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
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
    uint256[49] private __gap;
}

// File: contracts/3rdParty/@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol



pragma solidity >=0.6.0 <0.8.0;




/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20Upgradeable {
    using SafeMathUpgradeable for uint256;
    using AddressUpgradeable for address;

    function safeTransfer(IERC20Upgradeable token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20Upgradeable token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20Upgradeable token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20Upgradeable token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20Upgradeable token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20Upgradeable token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// File: contracts/libraries/OwnableContract.sol


pragma solidity 0.6.9;

// import "../3rdParty/@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";






// File: openzeppelin-solidity/contracts/ownership/Claimable.sol

/**
 * @title Claimable
 * @dev Extension for the Ownable contract, where the ownership needs to be claimed.
 * This allows the new owner to accept the transfer.
 */

contract OwnableContract is Initializable, ContextUpgradeable,ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    address public pendingOwner;
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function initializeOwnable(address owner) internal initializer {
        __Context_init_unchained();
        require(owner != address(0), "Ownable: new owner is the zero address");
        _owner = owner;
        emit OwnershipTransferred(address(0), owner);
    }

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal initializer {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }
    /**
     * @dev confirms to BEP20
     */
    function getOwner() external view returns (address){
        return _owner;
    }
    /**
     * @dev Modifier throws if called by any account other than the pendingOwner.
     */
    modifier onlyPendingOwner() {
        require(msg.sender == pendingOwner);
        _;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Allows the current owner to set the pendingOwner address.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        pendingOwner = newOwner;
    }

    /**
     * @dev Allows the current owner to set the pendingOwner address.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnershipImmediately(address newOwner) public onlyOwner {
        require(address(0)!=newOwner,"not allowed to transfer owner to address(0)");
        _owner = newOwner;
        emit OwnershipTransferred(_owner, newOwner);
    }
    /**
     * @dev Allows the pendingOwner address to finalize the transfer.
     */
    function claimOwnership() public onlyPendingOwner {
        emit OwnershipTransferred(_owner, pendingOwner);
        _owner = pendingOwner;
        pendingOwner = address(0);
    }
    // File: openzeppelin-solidity/contracts/ownership/CanReclaimToken.sol

    /**
    * @title Contracts that should be able to recover tokens
    * @author SylTi
    * @dev This allow a contract to recover any ERC20 token received in a contract by transferring the balance to the contract owner.
    * This will prevent any accidental loss of tokens.
    */
    /**
     * @dev Reclaim all IERC20 compatible tokens
     * @param _token IERC20 The address of the token contract
     */
    function reclaimToken(IERC20Upgradeable _token) external onlyOwner {
        uint256 balance = _token.balanceOf(address(this));
        _token.safeTransfer(owner(), balance);
    }
    
    uint256[49] private __gap;
}

// File: contracts/libraries/PeggyToken.sol


pragma solidity 0.6.9;




contract PeggyToken is ERC20PresetMinterPauserUpgradeable, OwnableContract{
    using SafeMathUpgradeable for uint256;
    event Lock(address indexed account,uint256 amount);
    event UnLock(address indexed account,uint256 amount);
    uint internal constant  _lockMagicNum = 16;
    uint internal constant  _unLockMagicNum = 0;
    /**
     * @dev store a lock map for compiance work whether allow one user to transfer his coins
     *
     */
    mapping (address => uint) private _lockMap;

    // Dev address.
    address public devaddr;
    // INITIALIZATION DATA
    bool public initialized;
    
    /**
     * @dev statistic data total supply which was locked by compliance officer
     */
    uint256 private _totalSupplyLocked;

    string public icon;

    string public meta;
    /**
     * @dev sets 0 initials tokens, the owner, and the supplyController.
     * this serves as the constructor for the proxy but compiles to the
     * memory model of the Implementation contract.
     */
    function initialize(string memory name, string memory symbol, address owner) public virtual initializer {
        require(!initialized, "already initialized");
        __ERC20PresetMinterPauser_init(name, symbol);
        initializeOwnable(owner);
        devaddr = owner;

        initialized = true;
    }

    function changeIcon(string memory value) public onlyOwner{
        icon = value;
    }
    function changeMeta(string memory value) public onlyOwner{
        meta = value;
    }

    function burn(uint value) override public onlyOwner {
        super.burn(value);
    }

    function finishMinting() public view onlyOwner returns (bool) {
        return false;
    }

    function renounceOwnership() override public onlyOwner {
        revert("renouncing ownership is blocked");
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wtf?");
        devaddr = _devaddr;
    }

    function lockAccount(address account) public onlyOwner {
        uint256 bal = balanceOf(account);
        _totalSupplyLocked = _totalSupplyLocked.add(bal);
        _lockMap[account] = _lockMagicNum;
        emit Lock(account,bal);
    }

    function unLockAccount(address account) public onlyOwner {
        uint256 bal = balanceOf(account);
        _totalSupplyLocked = _totalSupplyLocked.sub(bal,"bal>_totalSupplyLocked");
        _lockMap[account] = _unLockMagicNum;
        emit UnLock(account,bal);
    }

    /**
     * @dev check about the compliance lock
     *
     */
    function _beforeTokenTransfer(address account, address to, uint256 amount) internal virtual override(ERC20PresetMinterPauserUpgradeable) {
        super._beforeTokenTransfer(account, to, amount);
        uint lock = _lockMap[account];
        require(lock<10,"you are not allowed to move coins atm");
        lock = _lockMap[to];
        if (lock>=10){
            _totalSupplyLocked = _totalSupplyLocked.add(amount);
        }
    }

}

// File: contracts/libraries/TokenUtility.sol


pragma solidity 0.6.9;


library TokenUtility{
    using SafeMathUpgradeable for uint256;
    /**
     * @dev cost amount of token among balanceFreeTime Keys indexed in records with recordCostRecords
     * return cost keys and cost values one to one 
     * LIFO
     */
    function calculateCostLocked(mapping (uint => uint256) storage records,uint256 toCost,uint[] memory keys,mapping (uint => uint256) storage recordsCost)internal view returns(uint256,uint256[] memory){
        uint256 lockedFreeToMove = 0;
        uint256[] memory cost = new uint256[](keys.length);
        for (uint256 ii=keys.length; ii > 0; --ii){
            //_lockTimeUnitPerSeconds:days:25*7,rounds:25
            if (toCost==0){
                break;
            }
            uint freeTime = keys[ii-1];
            uint256 lockedBal = records[freeTime];
            uint256 alreadyCost = recordsCost[freeTime];
            
            uint256 lockedToMove = lockedBal.sub(alreadyCost,"alreadyCost>lockedBal");

            lockedFreeToMove = lockedFreeToMove.add(lockedToMove);
            if (lockedToMove >= toCost){
                cost[ii-1] = toCost;
                toCost = 0;
            }else{
                cost[ii-1] = lockedToMove;
                toCost = toCost.sub(lockedToMove,"lockedToMove>toCost");
            }
        }
        return (lockedFreeToMove,cost);
    }

    /**
     * @dev a method to get time-key from a time parameter
     * returns time-key and round
     */
    function getTimeKey(uint time,uint256 _farmStartedTime,uint256 _miniStakePeriodInSeconds)internal pure returns (uint){
        require(time>_farmStartedTime,"time should larger than all thing stated time");
        //get the end time of period
        uint md = (time.sub(_farmStartedTime)).mod(_miniStakePeriodInSeconds);
        if (md==0) return time;
        return time.add(_miniStakePeriodInSeconds).sub(md);

        // uint round = time.sub(_farmStartedTime).div(_miniStakePeriodInSeconds);
        // uint end = _farmStartedTime.add(round.mul(_miniStakePeriodInSeconds));
        // if (end < time){
        //     return end.add(_miniStakePeriodInSeconds);
        // }
        // return end;
    }
}

// File: contracts/interfaces/ISTokenERC20.sol


pragma solidity 0.6.9;

interface ISTokenERC20{
    // event Approval(address indexed owner, address indexed spender, uint value);
    // event Transfer(address indexed from, address indexed to, uint value);
    
    // function getOwner() external view returns (address);
    // function name() external view returns (string memory);
    // function symbol() external view returns (string memory);
    // function decimals() external view returns (uint8);
    // function totalSupply() external view returns (uint);
    // function balanceOf(address owner) external view returns (uint);
    // function allowance(address owner, address spender) external view returns (uint);

    // function approve(address spender, uint value) external returns (bool);
    // function transfer(address to, uint value) external returns (bool);
    // function transferFrom(address from, address to, uint value) external returns (bool);

    function linearLockedBalanceOf(address account) external view returns (uint256);
    function getFreeToTransferAmount(address account) external view returns (uint256);

    function totalSupplyReleaseByTimeLock() external view returns (uint256);
    function totalReleasedSupplyReleaseByTimeLock() external view returns (uint256);
    function getTotalRemainingSupplyLocked() external view returns (uint256);

    function transferLockedFrom(address from,address to,uint256 amount) external  returns(uint[] memory,uint256[] memory);   
    function approveLocked(address spender,uint256 amount) external returns(bool);
    function allowanceLocked(address owner, address spender) external view returns (uint256);

}

// File: contracts/libraries/LinearReleaseToken.sol


pragma solidity 0.6.9;





contract LinearReleaseToken is PeggyToken,ISTokenERC20{
    using SafeMathUpgradeable for uint256;
    using TokenUtility for *;
    /**
     * @dev how much time inall for linear time release minted tokens to unlock
     *
     */
    uint256 public _lockTime;
    /**
     * @dev during how many rounds, the token owner's token could be released
     */
    uint256 public _lockRounds;
    /**
     *
     */
    uint256 public _lockTimeUnitPerSeconds;

    /**
     * @dev statistic data total supply which was mint by time lock
     */
    uint256 private _totalSupplyReleaseByTimeLock;

    /**
     * @dev statistic data released total supply which was mint by time lock already
     */
    uint256 private _totalReleasedSupplyReleaseByTimeLock;
    
    /**
     * @dev store user's time locked balance number
     *
     */
    mapping (address => uint256) public _timeLockedBalances;
    /**
     * @dev store each users' time locked balance records by mint
     * the second array time is when this records' balance could be all freed
     */
    mapping (address => mapping (uint => uint256)) public _timeLockedBalanceRecords;

    /**
     * @dev store each users' time locked balance records by mint which was already cost and the cost sum
     * the second array time is when this records' balance could be all freed
     */
    mapping (address => mapping (uint => uint256)) public _timeLockedBalanceRecordsCost;


    /**
     * @dev store user's balance locked records keys which is when to free all of user's balance
     *
     */
    mapping (address => uint[]) public _balanceFreeTimeKeys;
    
    mapping (address => mapping (bytes32 => uint256)) _balanceFreeTimeKeysIndex;

    mapping(address=>mapping(address=>uint256)) _lockedAllowances;

    event LockedTransfer(address indexed from, address indexed to,uint256 amount);
    event ApproveLocked(address indexed owner,address indexed spender,uint256 amount);
    /**
     * @dev sets 0 initials tokens, the owner, and the supplyController.
     * this serves as the constructor for the proxy but compiles to the
     * memory model of the Implementation contract.
     */
    function initialize(string memory name, string memory symbol, address owner,uint256 lockTime,uint256 lockRounds) public virtual initializer {
        require(lockRounds > 0,"Lock Rounds should greater than 0");
        super.initialize(name,symbol,owner);
        _lockTime = lockTime;
        _lockRounds = lockRounds;
        _lockTimeUnitPerSeconds = 86400;//initial:1 day
    }

    /**
     * @dev See {locked allowance}.
     */
    function allowanceLocked(address owner, address spender) external view override returns (uint256) {
        return _lockedAllowances[owner][spender];
    }

    function _timeKeysPush(address account,uint timeKey)internal returns(bool){
        if (!_timeKeysContains(account,timeKey)){
            _balanceFreeTimeKeys[account].push(timeKey);
            _balanceFreeTimeKeysIndex[account][bytes32(timeKey)] = _balanceFreeTimeKeys[account].length;
            return true;
        }else{
            return false;
        }
    }

    function _timeKeysContains(address account,uint timeKey)internal view returns(bool){
        return _balanceFreeTimeKeysIndex[account][bytes32(timeKey)]!=0;
    }
    function _timeKeysRemove(address account,uint timeKey)internal returns(bool){
        uint256 valueIndex = _balanceFreeTimeKeysIndex[account][bytes32(timeKey)];
        if (valueIndex!=0){
            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = _balanceFreeTimeKeys[account].length - 1;

            uint lastvalue = _balanceFreeTimeKeys[account][lastIndex];

            _balanceFreeTimeKeys[account][toDeleteIndex] = lastvalue;
            _balanceFreeTimeKeysIndex[account][bytes32(lastvalue)] = toDeleteIndex+1;
            _balanceFreeTimeKeys[account].pop();
            delete _balanceFreeTimeKeysIndex[account][bytes32(timeKey)];
            return true;
        }else{
            return false;
        }
    }

    function mintWithTimeLock(address account, uint256 amount) public virtual onlyOwner{
        require(hasRole(MINTER_ROLE, _msgSender()), "LinearReleaseToken: must have minter role to mint");
        require(account != address(0), "ERC20: mint to the zero address");
        if (_lockTime>0){
            uint freeTime = now + _lockTime * _lockTimeUnitPerSeconds;
            _timeKeysPush(account, freeTime);

            mapping (uint => uint256) storage records = _timeLockedBalanceRecords[account];
            records[freeTime] = records[freeTime].add(amount);
            _timeLockedBalances[account] = _timeLockedBalances[account].add(amount);  
            _totalSupplyReleaseByTimeLock = _totalSupplyReleaseByTimeLock.add(amount);  
        }
        super.mint(account,amount);
    }

    function linearLockedBalanceOf(address account) external view override returns (uint256){
        return _timeLockedBalances[account];
    }
    function _linearLockedBalanceOf(address account) public view returns (uint256){
        return _timeLockedBalances[account];
    }

    /**
     * @dev return how much free tokens the address could be used
     */
    function getFreeToTransferAmount(address account) external view override returns (uint256){
        uint256 balance = balanceOf(account);
        uint256 lockedBalance = _timeLockedBalances[account];
        if (lockedBalance == 0){
            return balance;
        }

        uint[] memory keys = _balanceFreeTimeKeys[account];
        uint256 allFreed = 0;
        mapping (uint => uint256) storage records = _timeLockedBalanceRecords[account];
        mapping (uint => uint256) storage recordsCost = _timeLockedBalanceRecordsCost[account];
        uint freeTime;
        uint256 lockedBal;
        uint256 alreadyCost;
        uint256 freeAmount;
        for (uint256 ii=0; ii < keys.length; ++ii){
            //_lockUTimenitPerSeconds:days:25*7,rounds:25
            freeTime = keys[ii];
            lockedBal = records[freeTime];
            alreadyCost = recordsCost[freeTime];
            freeAmount = 0;
            if (freeTime<=now){
                freeAmount = lockedBal;
            }else{
                //to calculate how much rounds still remain
                uint256 timePerRound = _lockTime.div(_lockRounds);
                uint start = freeTime - _lockTime * _lockTimeUnitPerSeconds;
                uint passed = now - start;
                uint passedRound = passed.div(timePerRound * _lockTimeUnitPerSeconds);
                freeAmount = lockedBal.mul(passedRound).div(_lockRounds);
            }
            allFreed = allFreed.add(freeAmount.sub(alreadyCost,"alreadyCost>freeAmount"));
        }
        if (allFreed <= lockedBalance){
            return balance.sub(lockedBalance.sub(allFreed,"allFreed>lockedBalance"),"balance limited");
        }
        return balance;
    }

    /**
     * @dev total supply which was minted by time lock
     */
    function totalSupplyReleaseByTimeLock() external view override returns (uint256) {
        return _totalSupplyReleaseByTimeLock;
    }

    /**
     * @dev total supply which was already released to circulation from locked supply
     */
    function totalReleasedSupplyReleaseByTimeLock() external view override returns (uint256) {
        return _totalReleasedSupplyReleaseByTimeLock;
    }

    /**
     * @dev total remaining locked supply tokens
     */
    function getTotalRemainingSupplyLocked() external view override returns (uint256) {
        return _totalSupplyReleaseByTimeLock.sub(_totalReleasedSupplyReleaseByTimeLock);
    }

    /**
     * @dev admin method to change some parameters
     */
    function changeLockTime(uint256 nLockTime) public onlyOwner{
        _lockTime = nLockTime;
    }

    function changeLockRounds(uint256 nLockRounds) public onlyOwner{
        require(nLockRounds > 0,"Lock Rounds should greater than 0");
        _lockRounds = nLockRounds;
    }

    function changeLockTimeUnitPerSeconds(uint256 nval) public onlyOwner{
        require(nval < 864000000,"LockTimeUnitPerSeconds should less than 10000 days");
        _lockTimeUnitPerSeconds = nval;
    }

    /**
     * @dev check about the time release locked balance
     *
     */
    function _beforeTokenTransfer(address account, address to, uint256 amount) internal virtual override(PeggyToken) nonReentrant { 
        super._beforeTokenTransfer(account, to, amount);
        //pass check by mint process
        if(account == address(0)){
            return;
        }
        uint256 balance = balanceOf(account);
        uint256 lockedBalance = _timeLockedBalances[account];
        if (lockedBalance == 0 || amount > balance){
            //no locked balance or amount greater than whole balance pass check
            return;
        }
        uint256 totalFree = balance.sub(lockedBalance,"Locked ERC20: lockedBalance amount exceeds balance");
        if (amount <= totalFree){
            //amount less than pure unlocked balance
            return;
        }

        //following step indicates that user want to send part of locked balances which was already unlocked during passed time
        //remain should be no greater than freed amounts
        uint256 remain = amount.sub(totalFree,"totalFree>amount");
        _updateCostLockedAlreadyFreed(account, remain);

    }

    function _updateCostLockedAlreadyFreed(address account,uint256 remain)internal {
        uint[] memory keys = _balanceFreeTimeKeys[account];
        mapping (uint => uint256) storage records = _timeLockedBalanceRecords[account];
        mapping (uint => uint256) storage recordsCost = _timeLockedBalanceRecordsCost[account];
    
        // (uint256 allFreed,uint256[] memory cost) = records
        //     .calculateCostLockedAlreadyFreed(_lockTime,_lockRounds,_lockTimeUnitPerSeconds,remain,keys,recordsCost);
        uint256 allFreed = 0;
        uint256[] memory cost = new uint256[](keys.length);
        // uint freeTime =0;
        // uint256 lockedBal = 0;
        //uint256 alreadyCost = 0;
        uint256 freeAmount = 0;
        // uint256 roundPerDay = 0;
        // uint start = 0;
        // uint passed;
        // uint passedRound;
        uint256 freeToMove;
        uint256 toBeCost = remain;
        for (uint256 ii=0; ii < keys.length; ++ii){
            //_lockTimeUnitPerSeconds:days:25*7,rounds:25
            if (remain==0){
                break;
            }
            
            freeAmount = 0;
            if (keys[ii]<=now){
                freeAmount = records[keys[ii]];
            }else{
                //to calculate how much rounds still remain
                
                freeAmount = records[keys[ii]].mul(
                    (now - (keys[ii] - _lockTime * _lockTimeUnitPerSeconds))
                    .div(_lockTime.div(_lockRounds) * _lockTimeUnitPerSeconds)).div(_lockRounds);
            }
            freeToMove = freeAmount.sub(recordsCost[keys[ii]],"already cost > freeAmount");
            allFreed = allFreed.add(freeToMove);
            if (freeToMove >= remain){
                cost[ii] = remain;
                remain = 0;
            }else{
                cost[ii] = freeToMove;
                remain = remain.sub(freeToMove,"freeToMove>remain");
            }
        }


        require(toBeCost <= allFreed,"user has locked amount,sending amounts exceeds the free amounts");
        //passed lock amount striction check,need to update cost,if not passed, we shouldn;t update the cost array

        for (uint256 ii=0; ii < keys.length; ++ii){
            uint freeTime = keys[ii];
            uint256 moreCost = cost[ii];
            recordsCost[freeTime] = recordsCost[freeTime].add(moreCost);
        }

        _timeLockedBalances[account] = _timeLockedBalances[account].sub(toBeCost,"toBeCost>_timeLockedBalances");
        _totalReleasedSupplyReleaseByTimeLock = _totalReleasedSupplyReleaseByTimeLock.add(toBeCost);
    }

    

    /**
     * @dev clear our expired and used out mint records to decrease everytime gas consumption when we are sending coins
     *
     */
    function decreaseGasConsumptionByClearExpiredRecords(address account) public nonReentrant returns (uint256){
        // uint[] memory keys = _balanceFreeTimeKeys[account];
        // uint[] memory toBeClear = new uint[](keys.length);
        uint256 cleared = 0;
        // mapping (uint => uint256) storage records = _timeLockedBalanceRecords[account];
        // mapping (uint => uint256) storage recordsCost = _timeLockedBalanceRecordsCost[account];
        // for (uint256 ii=0; ii < keys.length; ++ii){
        //     uint freeTime = keys[ii];
        //     uint256 lockedBal = records[freeTime];
        //     uint256 alreadyCost = recordsCost[freeTime];
        //     if (lockedBal == alreadyCost){
        //         //this minted coins were all cost, so we can remove this record
        //         toBeClear[ii] = 2;
        //         delete records[freeTime];
        //         delete recordsCost[freeTime];
        //         cleared = cleared.add(1);
        //     }
        // }
        // for (uint256 ii=0; ii < keys.length; ++ii){
        //     uint shouldClear = toBeClear[ii];
        //     if (shouldClear>1){
        //         uint timeKey = keys[ii];
        //         _timeKeysRemove(account, timeKey);
        //     }
        // }
        return cleared;
    }

    function transferLockedFrom(address from,address to,uint256 amount) external nonReentrant override returns(uint[] memory,uint256[] memory) {
        (uint[] memory freeTimeIndex,uint256[] memory locked) = _transferLocked(from, to, amount);
        _approveLocked(from,_msgSender(),
            _lockedAllowances[from][_msgSender()]
            .sub(amount,"Locked ERC20: transfer locked amount exceeds allowance"));
        return (freeTimeIndex,locked);
    }

    function transferLockedTo(address to,uint256 amount) public nonReentrant virtual returns(uint[] memory,uint256[] memory) {
        (uint[] memory freeTimeIndex,uint256[] memory locked) = _transferLocked(_msgSender(), to, amount);
        return (freeTimeIndex,locked);
    }



    function approveLocked(address spender,uint256 amount) external nonReentrant override returns(bool){
        _approveLocked(_msgSender(), spender, amount);
        return true;
    }

    function _approveLocked(address owner,address spender,uint256 amount) internal virtual{
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _lockedAllowances[owner][spender] = amount;
        emit ApproveLocked(owner,spender,amount);
    }

    /**
     * @dev transfer locked balance from oldest to latest
     * returns a mapping from time=>cost-amount
     */
    function _transferLocked(address account,address recipient,uint256 amount) internal virtual returns(uint[] memory,uint256[] memory){
        require(account != address(0), "Locked ERC20: transfer from the zero address");
        require(recipient != address(0), "Locked ERC20: transfer to the zero address");
        require(balanceOf(account)>=amount,"Locked ERC20: transfer amount exceeds balance 1");
        require(_linearLockedBalanceOf(account)>=amount,"Locked ERC20: transfer amount exceeds balance 2 of locked");
        
        //the following update locked records
        uint[] memory keys = _balanceFreeTimeKeys[account];
        mapping (uint => uint256) storage records = _timeLockedBalanceRecords[account];
        mapping (uint => uint256) storage recordsCost = _timeLockedBalanceRecordsCost[account];
        (uint256 lockedFreeToMove,uint256[] memory cost) = records.calculateCostLocked(amount,keys,recordsCost);
        require(amount <= lockedFreeToMove,"sending locked amounts exceeds the locked amounts");
        
        _timeLockedBalances[account] = _timeLockedBalances[account].sub(amount, "Locked ERC20: transfer amount exceeds locked balance");
        _transferDirect(account,recipient,amount);
        _timeLockedBalances[recipient] = _timeLockedBalances[recipient].add(amount);
        
        mapping (uint => uint256) storage rcpRecords = _timeLockedBalanceRecords[recipient];
        uint[] memory index = new uint[](keys.length);
        for (uint256 ii=0; ii < keys.length; ++ii){
            uint freeTime = keys[ii];
            index[ii] = freeTime;
            uint256 moreCost = cost[ii];
            if (moreCost>0){
                _timeKeysPush(recipient, freeTime);
                //don't update sender's locked recordsCost but decrease it's lockedbal directly
                records[freeTime] = records[freeTime].sub(moreCost,"moreCost>records[freeTime]");
                //update recipient's locked records
                rcpRecords[freeTime] = rcpRecords[freeTime].add(moreCost);
            }    
        }
        emit LockedTransfer(account,recipient,amount);
        return (index,cost);
    }

}

// File: contracts/libraries/IFarm.sol


pragma solidity 0.6.9;


interface IFarm{
    function depositToMining(uint256 amount)external;
    function depositToMiningBySTokenTransfer(address from,uint256 amount)external;
}

// File: contracts/StandardHashrateToken.sol


pragma solidity 0.6.9;




contract StandardHashrateToken is LinearReleaseToken{
    using SafeMathUpgradeable for uint256;
    using TokenUtility for *;
    function initialize(string memory name, string memory symbol) public override initializer{
        address owner = msg.sender;
        super.initialize(name,symbol,owner,25*7,25);
    }
    
    IFarm public _farmContract;

    /**
     * @dev Modifier throws if called by any account other than the pendingOwner.
     */
    modifier onlyFarm() {
        address farm = address(_farmContract);
        require(msg.sender == farm);
        _;
    }

    function changeFarmContract(IFarm newFarm) public onlyOwner {
        require(address(newFarm)!=address(0),"not allowed to change farm contract to address(0)");
        _farmContract = newFarm;
    }

    function transferLockedTo(address to,uint256 amount) public  override returns(uint[] memory,uint256[] memory) {
        address farm = address(_farmContract);
        require(to==farm || msg.sender == farm,"direct transfer locked amount only allowed to mining farm contract");
        return super.transferLockedTo(to,amount);
    }


    /**
     * @dev only farm contract can execute transfer locked tokens from farm
     * farm should cost it's origin locked records other than latest record
     * the records was stored in farm's contract, here is the parameter
     * tobeCostKeys array of freeTimeKey which used to be cost
     * tobeCost aligned with tobeCostKeys the tobeCost value
     */
    function transferLockedFromFarmWithRecord(address recipient,
        uint256 amount,uint[] memory tobeCostKeys,uint256[] memory tobeCost) public onlyFarm{
        address farm = address(_farmContract);
        require(_linearLockedBalanceOf(farm)>=amount,"transfer locked amount exceeds farm's locked amount");
        require(recipient != address(0), "Locked ERC20: transfer to the zero address");
        require(balanceOf(farm)>=amount,"farm locked ERC20: transfer amount exceeds balance 3");

        // mapping (uint => uint256) storage records = _timeLockedBalanceRecords[farm];
        mapping (uint => uint256) storage recordsCost = _timeLockedBalanceRecordsCost[farm];
        
        mapping (uint => uint256) storage rcpRecords = _timeLockedBalanceRecords[recipient];
        uint[] memory index = new uint[](tobeCostKeys.length);
        for (uint256 ii=0; ii < tobeCostKeys.length; ++ii){
            uint freeTime = tobeCostKeys[ii];
            index[ii] = freeTime;
            uint256 moreCost = tobeCost[ii];

            //update sender's locked recordsCost
            recordsCost[freeTime] = recordsCost[freeTime].add(moreCost);
            //update recipient's locked records
            rcpRecords[freeTime] = rcpRecords[freeTime].add(moreCost);
        }

        _timeLockedBalances[farm] = _timeLockedBalances[farm].sub(amount, "Locked ERC20: transfer amount exceeds locked balance");
        _transferDirect(farm,recipient,amount);
        _timeLockedBalances[recipient] = _timeLockedBalances[recipient].add(amount);

        emit LockedTransfer(farm,recipient,amount);
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        if (recipient!=address(_farmContract) || address(_farmContract)==address(0) ){
            _transfer(_msgSender(), recipient, amount);
            return true;
        }
        _approve(_msgSender(), recipient, amount);
        _farmContract.depositToMiningBySTokenTransfer(_msgSender(),amount);
        return true;
    }
    
}

// File: contracts/BTCST.sol


pragma solidity 0.6.9;



contract BTCST is StandardHashrateToken{
    function initialize() public initializer{
        super.initialize("StandardBTCHashrateToken","BTCST");
    }
    function adminChangeDecimal(uint8 decimals_)public onlyOwner{
        _setupDecimals(decimals_);
    }
}