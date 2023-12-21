// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "ERC20PausableUpgradeable.sol";
import "ERC20CappedUpgradeable.sol";
import "ERC20BurnableUpgradeable.sol";
import "AccessControlEnumerableUpgradeable.sol";
import "ContextUpgradeable.sol";
import "EIP712Upgradeable.sol";
import "CountersUpgradeable.sol";
import "Initializable.sol";


contract SPEXYToken is 
    Initializable,
    ContextUpgradeable,
    AccessControlEnumerableUpgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    EIP712Upgradeable 
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    mapping(address => bool) public isTrustedForwarder;
    mapping(address => CountersUpgradeable.Counter) private _nonces;

    bytes32 public constant SPX = keccak256("SPEXY_1_0");

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // solhint-disable-next-line var-name-mixedcase
    bytes32 private constant _PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    function initialize(string memory name, string memory symbol) public virtual initializer {
        __ERC20_init_unchained(name, symbol);
        __Pausable_init_unchained();
        __ERC20Burnable_init();
        __ERC20PresetPauser_init_unchained(name, symbol);
        __EIP712_init_unchained(name, "1");
    }

    function __ERC20PresetPauser_init_unchained(string memory, string memory) internal onlyInitializing {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _setupRole(PAUSER_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        require(block.timestamp <= deadline, "ERC20Permit: expired deadline");

        bytes32 structHash = keccak256(abi.encode(_PERMIT_TYPEHASH, owner, spender, value, _useNonce(owner), deadline));

        bytes32 hash = _hashTypedDataV4(structHash);

        address signer = ECDSAUpgradeable.recover(hash, v, r, s);
        require(signer == owner, "ERC20Permit: invalid signature");

        _approve(owner, spender, value);
    }

    function nonces(address owner) public view virtual returns (uint256) {
        return _nonces[owner].current();
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    function pause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "ERC20PresetMinterPauser: must have pauser role to pause");
        _pause();
    }

    function unpause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "ERC20: must have pauser role to unpause");
        _unpause();
    }

    function mint(address to, uint256 amount) public {
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC20: must have minter role to mint");
        _mint(to, amount);
    }

    function burn(uint256 amount) public override {
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC20: must have minter role to burn");
        _burn(_msgSender(), amount);
    }

    function adminSetForwarder(address forwarder, bool valid) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "ERC20: must have admin role to set");
        isTrustedForwarder[forwarder] = valid;
    }

    function _msgSender() internal override view returns (address) {
        address signer = msg.sender;
        if (msg.data.length >= 20 && isTrustedForwarder[signer]) {
            assembly {
                signer := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        }
        return signer;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _useNonce(address owner) internal virtual returns (uint256 current) {
        CountersUpgradeable.Counter storage nonce = _nonces[owner];
        current = nonce.current();
        nonce.increment();
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    uint256[50] private __gap;
}