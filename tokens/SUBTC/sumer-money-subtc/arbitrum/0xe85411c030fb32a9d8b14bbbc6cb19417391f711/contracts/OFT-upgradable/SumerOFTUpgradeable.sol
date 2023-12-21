// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./OFTUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

contract SumerOFTUpgradeable is
    OFTUpgradeable,
    EIP712Upgradeable,
    PausableUpgradeable
{
    uint256 private _cap;
    mapping(address => bool) private _blackList;
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH =
        0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    mapping(address => uint256) public nonces;

    function initialize(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply,
        address _lzEndpoint
    ) public initializer {
        __ExampleOFTUpgradeable_init(
            _name,
            _symbol,
            _initialSupply,
            _lzEndpoint
        );
    }

    function __ExampleOFTUpgradeable_init(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply,
        address _lzEndpoint
    ) internal onlyInitializing {
        __OFTUpgradeable_init(_name, _symbol, _lzEndpoint);
        __EIP712_init(_name, "v1.0");
        __ExampleOFTUpgradeable_init_unchained(
            _name,
            _symbol,
            _initialSupply,
            _lzEndpoint
        );
    }

    function __ExampleOFTUpgradeable_init_unchained(
        string memory,
        string memory,
        uint256 _initialSupply,
        address
    ) internal onlyInitializing {
        _mint(_msgSender(), _initialSupply);
    }

    /**
     * @dev Returns the cap on the token's total supply.
     */
    function cap() public view virtual returns (uint256) {
        return _cap;
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
    function mint(address to, uint256 amount) public {
        require(
            hasRole(MINTER_ROLE, _msgSender()),
            "ERC20PresetMinterPauser: must have minter role to mint"
        );
        if (_cap > 0) {
            require(
                totalSupply() + amount <= _cap,
                "ERC20Capped: cap exceeded"
            );
        }
        _mint(to, amount);
    }

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
        _spendAllowance(account, _msgSender(), amount);
        _burn(account, amount);
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
    function pause() public {
        require(
            hasRole(PAUSER_ROLE, _msgSender()),
            "ERC20PresetMinterPauser: must have pauser role to pause"
        );
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
        require(
            hasRole(PAUSER_ROLE, _msgSender()),
            "ERC20PresetMinterPauser: must have pauser role to unpause"
        );
        _unpause();
    }

    function setCap(uint256 cap_) public {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "ERC20PresetMinterPauser: must have adfmin role to set cap"
        );
        _cap = cap_;
    }

    function setBlackList(address account) public {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "ERC20PresetMinterPauser: must have adfmin role to set black list"
        );
        _blackList[account] = !_blackList[account];
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
    ) internal override {
        super._beforeTokenTransfer(from, to, amount);
        require(
            !_blackList[from] && !_blackList[to],
            "ERC20Pausable: account is in black list"
        );
        require(!paused(), "ERC20Pausable: token transfer while paused");
        if (from == address(0)) {
            require(
                _cap == 0 || (_cap > 0 && totalSupply() + amount <= _cap),
                "ERC20Capped: cap exceeded"
            );
        }
    }

    function permit(
        address signer,
        address spender,
        uint256 value,
        uint256 deadline,
        bytes memory signature
    ) external returns (bool) {
        require(deadline >= block.timestamp, "expired!");
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                signer,
                spender,
                value,
                nonces[signer]++,
                deadline
            )
        );
        bytes32 hash = _hashTypedDataV4(structHash);
        require(
            ECDSAUpgradeable.recover(hash, signature) == signer,
            "Permit: invalid signature"
        );
        _spendAllowance(signer, spender, value);
        return true;
    }
}
