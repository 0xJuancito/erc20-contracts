// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

import "../library/Initializable.sol";
import "../library/Ownable.sol";
import "../library/ERC20.sol";

/**
 * @title dForce's Multi-currency Stable Debt Token
 * @author dForce
 */
contract MSD is Initializable, Ownable, ERC20 {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    bytes32 public DOMAIN_SEPARATOR;
    // keccak256("Permit(address owner,address spender,uint256 chainId, uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH =
        0x576144ed657c8304561e56ca632e17751956250114636e8c01f64a7f2c6d98cf;
    mapping(address => uint256) public nonces;

    /// @dev EnumerableSet of minters
    EnumerableSetUpgradeable.AddressSet internal minters;

    /**
     * @dev Emitted when `minter` is added as `minter`.
     */
    event MinterAdded(address minter);

    /**
     * @dev Emitted when `minter` is removed from `minters`.
     */
    event MinterRemoved(address minter);

    /**
     * @notice Expects to call only once to initialize the MSD token.
     * @param _name Token name.
     * @param _symbol Token symbol.
     */
    function initialize(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) external initializer {
        __Ownable_init();
        __ERC20_init(_name, _symbol, _decimals);

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(_name)),
                keccak256(bytes("1")),
                _getChainId(),
                address(this)
            )
        );
    }

    /**
     * @dev Throws if called by any account other than the minters.
     */
    modifier onlyMinter() {
        require(
            minters.contains(msg.sender),
            "onlyMinter: caller is not minter"
        );
        _;
    }

    /**
     * @notice Add `minter` into minters.
     * If `minter` have not been a minter, emits a `MinterAdded` event.
     *
     * @param _minter The minter to add
     *
     * Requirements:
     * - the caller must be `owner`.
     */
    function _addMinter(address _minter) external onlyOwner {
        require(_minter != address(0), "_addMinter: _minter the zero address");
        if (minters.add(_minter)) {
            emit MinterAdded(_minter);
        }
    }

    /**
     * @notice Remove `minter` from minters.
     * If `minter` is a minter, emits a `MinterRemoved` event.
     *
     * @param _minter The minter to remove
     *
     * Requirements:
     * - the caller must be `owner`.
     */
    function _removeMinter(address _minter) external onlyOwner {
        require(
            _minter != address(0),
            "_removeMinter: _minter the zero address"
        );
        if (minters.remove(_minter)) {
            emit MinterRemoved(_minter);
        }
    }

    function mint(address to, uint256 amount) external onlyMinter {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burnFrom(from, amount);
    }

    function _getChainId() internal pure returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }

    /**
     * @dev EIP2612 permit function. For more details, please look at here:
     * https://eips.ethereum.org/EIPS/eip-2612
     * @param _owner The owner of the funds.
     * @param _spender The spender.
     * @param _value The amount.
     * @param _deadline The deadline timestamp, type(uint256).max for max deadline.
     * @param _v Signature param.
     * @param _s Signature param.
     * @param _r Signature param.
     */
    function permit(
        address _owner,
        address _spender,
        uint256 _value,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {
        require(_deadline >= block.timestamp, "permit: EXPIRED!");
        uint256 _currentNonce = nonces[_owner];
        bytes32 _digest =
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR,
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            _owner,
                            _spender,
                            _getChainId(),
                            _value,
                            _currentNonce,
                            _deadline
                        )
                    )
                )
            );
        address _recoveredAddress = ecrecover(_digest, _v, _r, _s);
        require(
            _recoveredAddress != address(0) && _recoveredAddress == _owner,
            "permit: INVALID_SIGNATURE!"
        );
        nonces[_owner] = _currentNonce.add(1);
        _approve(_owner, _spender, _value);
    }

    /**
     * @notice Return all minters of this MSD token
     * @return _minters The list of minter addresses
     */
    function getMinters() public view returns (address[] memory _minters) {
        uint256 _len = minters.length();
        _minters = new address[](_len);
        for (uint256 i = 0; i < _len; i++) {
            _minters[i] = minters.at(i);
        }
    }
}
