// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "../interfaces/IUSDMToken.sol";
import "../refs/CoreRef.sol";

contract USDMToken is IUSDMToken, ERC20Burnable, CoreRef {
    using SafeMath for uint256;

    // solhint-disable-next-line var-name-mixedcase
    bytes32 public DOMAIN_SEPARATOR;
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH =
        0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    mapping(address => uint256) public nonces;

    event Mint(address indexed sender, uint256 amount);

    event Burn(address indexed sender, uint256 amount);

    /// @notice USDM token constructor
    /// @param _core USDM Core address to reference
    constructor(address _core) ERC20("USD Mars", "USDm") CoreRef(_core) {
        uint256 chainId;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name())),
                keccak256(bytes("1")),
                chainId,
                address(this)
            )
        );
    }

    /// @notice Mint USDM tokens
    /// @param account The account to mint to
    /// @param amount The amount to mint
    function mint(address account, uint256 amount)
        external
        override
        onlyMinter
        whenNotPaused
    {
        _mint(account, amount);
        emit Mint(account, amount);
    }

    /// @notice Burn USDM tokens from caller
    /// @param amount The amount to burn
    function burn(uint256 amount) public override(IUSDMToken, ERC20Burnable) {
        ERC20Burnable.burn(amount);
        emit Burn(msg.sender, amount);
    }

    /// @notice Permit spending of USDM
    /// @param owner The USDM holder
    /// @param spender The approved operator
    /// @param value The amount approved
    /// @param deadline The deadline after which the approval is no longer valid
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        // solhint-disable-next-line not-rely-on-time
        require(deadline >= block.timestamp, "USDMToken::permit: Expired");
        bytes32 digest =
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR,
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            owner,
                            spender,
                            value,
                            nonces[owner]++,
                            deadline
                        )
                    )
                )
            );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(
            recoveredAddress != address(0) && recoveredAddress == owner,
            "USDMToken::permit: Invalid signature"
        );
        _approve(owner, spender, value);
    }
}
