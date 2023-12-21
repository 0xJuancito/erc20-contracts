// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "./BEP20.sol";
import "./IBEP20.sol";
import "./Freezable.sol";
import "./TrustedContracts.sol";

contract Streakk is BEP20, Ownable, Freezable, TrustedContracts, EIP712 {
    mapping(address => mapping(uint256 => bool)) public isNonceUsed;
    mapping(address => uint256) public allotedToken;
    uint256 private _startTimestamp;
    uint256 public maxToken;

    struct Signature {
        bytes32 r;
        bytes32 s;
        uint8 v;
    }

    address public Community_Staking;
    address public Reserve;
    address public Treasury;
    address public Team;
    address public Web3Foundation;

    constructor(
        address owner,
        address _community_Staking,
        address _reserve,
        address _treasury,
        address _team,
        address _web3Foundation
    ) BEP20("Streakk Chain", "STKC") EIP712("Streakk Chain", "1") {
        Community_Staking = _community_Staking;
        Reserve = _reserve;
        Treasury = _treasury;
        Team = _team;
        Web3Foundation = _web3Foundation;

        _transferOwnership(owner);
        maxToken = 85_000_000 * 10 ** decimals();
        _startTimestamp = block.timestamp;

        //Add ammount of token should be alloted to respective addresses
        allotedToken[_community_Staking] = (maxToken * 50) / 100;
        allotedToken[_reserve] = (maxToken * 10) / 100;
        allotedToken[_treasury] = (maxToken * 15) / 100;
        allotedToken[_team] = (maxToken * 5) / 100;
        allotedToken[_web3Foundation] = (maxToken * 20) / 100;
    }

    function mint(
        address to,
        uint256 amount
    ) public unfreezed(to) noEmergencyFreeze onlyOwner {
        require(amount != 0, "cannot mint 0 tokens");
        require(
            allotedToken[to] >= amount,
            "amount is greater then the alloted supply left for this address"
        );
        require(
            maxToken >= (totalSupply() + amount),
            "max token limit exceeds"
        );
        // check if to address is Team address
        if (to == Team) {
            uint256 vestedPeriod = block.timestamp - _startTimestamp;
            require(
                vestedPeriod >= 21 * 30 days,
                "lock duration of 21 months for Team is not over yet"
            ); // check if vested period of Team is greater then 21 months
        }
        allotedToken[to] -= amount; // decrease amount from alloted amount
        _mint(to, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override unfreezed(from) unfreezed(to) noEmergencyFreeze {
        super._transfer(from, to, amount);
        notifyTrustedContract(from, to, amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal override noEmergencyFreeze {
        super._approve(owner, spender, amount);
    }

    function burn(
        address from,
        uint256 amount
    ) public onlyOwner noEmergencyFreeze {
        require(amount != 0, "cannot burn 0 tokens");
        _burn(from, amount);
    }

    function startTimestamp() public view returns (uint256) {
        return _startTimestamp;
    }

    function bulkTransfer(
        address[] memory to_addresses,
        uint256[] memory amounts
    ) public returns (bool) {
        require(to_addresses.length == amounts.length, "invalid length");
        for (uint256 i = 0; i < to_addresses.length; i++) {
            _transfer(msg.sender, to_addresses[i], amounts[i]);
        }
        return true;
    }

    function bulkTransferFrom(
        address sender,
        address[] memory to_addresses,
        uint256[] memory amounts
    ) public returns (bool) {
        require(to_addresses.length == amounts.length, "invalid length");
        for (uint256 i = 0; i < to_addresses.length; i++) {
            transferFrom(sender, to_addresses[i], amounts[i]);
        }
        return true;
    }

    function signedTransfer(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        uint256 nonce,
        bytes memory signature
    ) public {
        require(isNonceUsed[from][nonce] == false, "nonce already in use");
        _transferWithAuthorization(
            from,
            to,
            value,
            validAfter,
            validBefore,
            nonce,
            signature
        );
    }

    function signedApprove(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        uint256 nonce,
        bytes memory signature
    ) public {
        require(isNonceUsed[from][nonce] == false, "nonce already in use");
        _setApproveWithAuthorization(
            from,
            to,
            value,
            validAfter,
            validBefore,
            nonce,
            signature
        );
    }

    function signedIncreaseAllowance(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        uint256 nonce,
        bytes memory signature
    ) public {
        require(isNonceUsed[from][nonce] == false, "nonce already in use");
        _signedIncreaseAllowance(
            from,
            to,
            value,
            validAfter,
            validBefore,
            nonce,
            signature
        );
    }

    function signedDecreaseApproval(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        uint256 nonce,
        bytes memory signature
    ) public {
        require(isNonceUsed[from][nonce] == false, "nonce already in use");
        _signedDecreaseAllowance(
            from,
            to,
            value,
            validAfter,
            validBefore,
            nonce,
            signature
        );
    }

    function getSigner(
        bytes32 signedMessage,
        Signature calldata sig
    ) private pure returns (address) {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        return
            ecrecover(
                keccak256(abi.encodePacked(prefix, signedMessage)),
                sig.v,
                sig.r,
                sig.s
            );
    }

    function getChainID() public view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    function _setApproveWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        uint256 nonce,
        bytes memory signature
    ) internal {
        require(block.timestamp > validAfter, "authorization is not yet valid");
        require(block.timestamp < validBefore, "authorization is expired");
        bytes32 data = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256(
                        "signedApprove(uint256 chainID,address contractAddress,uint256 nonce,address from,address to,uint256 value,uint256 validAfter,uint256 validBefore)"
                    ),
                    getChainID(),
                    address(this),
                    nonce,
                    from,
                    to,
                    value,
                    validAfter,
                    validBefore
                )
            )
        );
        require(ECDSA.recover(data, signature) == from, "invalid signature");

        isNonceUsed[from][nonce] = true;
        _approve(from, to, value);
    }

    function _signedIncreaseAllowance(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        uint256 nonce,
        bytes memory signature
    ) public {
        require(block.timestamp > validAfter, "authorization is not yet valid");
        require(block.timestamp < validBefore, "authorization is expired");
        bytes32 data = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256(
                        "signedIncreaseAllowance(uint256 chainID,address contractAddress,uint256 nonce,address from,address to,uint256 value,uint256 validAfter,uint256 validBefore)"
                    ),
                    getChainID(),
                    address(this),
                    nonce,
                    from,
                    to,
                    value,
                    validAfter,
                    validBefore
                )
            )
        );
        require(ECDSA.recover(data, signature) == from, "invalid signature");
        isNonceUsed[from][nonce] = true;
        _approve(from, to, allowance(from, to) + value);
    }

    function _signedDecreaseAllowance(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        uint256 nonce,
        bytes memory signature
    ) public {
        require(block.timestamp > validAfter, "authorization is not yet valid");
        require(block.timestamp < validBefore, "authorization is expired");
        require(value <= allowance(from, to), "invalid value passed");
        bytes32 data = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256(
                        "signedDecreaseApproval(uint256 chainID,address contractAddress,uint256 nonce,address from,address to,uint256 value,uint256 validAfter,uint256 validBefore)"
                    ),
                    getChainID(),
                    address(this),
                    nonce,
                    from,
                    to,
                    value,
                    validAfter,
                    validBefore
                )
            )
        );
        require(ECDSA.recover(data, signature) == from, "invalid signature");
        isNonceUsed[from][nonce] = true;
        uint256 _value = allowance(from, to) - value;
        _approve(from, to, _value);
    }

    function _transferWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        uint256 nonce,
        bytes memory signature
    ) internal {
        require(block.timestamp > validAfter, "authorization is not yet valid");
        require(block.timestamp < validBefore, "authorization is expired");
        bytes32 data = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256(
                        "signedTransfer(uint256 chainID,address contractAddress,uint256 nonce,address from,address to,uint256 value,uint256 validAfter,uint256 validBefore)"
                    ),
                    getChainID(),
                    address(this),
                    nonce,
                    from,
                    to,
                    value,
                    validAfter,
                    validBefore
                )
            )
        );
        require(ECDSA.recover(data, signature) == from, "invalid signature");

        isNonceUsed[from][nonce] = true;
        _transfer(from, to, value);
    }
}
