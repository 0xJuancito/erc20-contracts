// contracts/Vigorus.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./@openzeppelin/contracts/access/AccessControl.sol";

contract Vigorus is ERC20, AccessControl {
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPE_HASH = 
            keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice The EIP-712 typehash for the approve struct used by the contract
    bytes32 public constant CLAIM_TYPE_HASH = 
            keccak256("Claim(address player,string txId,uint256 amount)");

    bytes32 public domainSeparator;

    /// @notice A record of states for signing / validating signatures
    mapping(address => bool) public signers;
    /// @notice A record of states for claimed transactions
    mapping(string => uint) public claimTransactions;

    event BurnForReason (
        uint amount,
        string reason
    );

    event SignerAdded (
        address signer
    );

    event SignerRemoved (
        address signer
    );

    event Claimed(
        address player,
        string txId,
        uint256 amount
    );

    constructor() ERC20("Vigorus", "VIS") {
        _setRoleAdmin(OWNER_ROLE, OWNER_ROLE);
        _setRoleAdmin(MINTER_ROLE, OWNER_ROLE);

        _setupRole(OWNER_ROLE, msg.sender);

        domainSeparator = keccak256(
            abi.encode(DOMAIN_TYPE_HASH, keccak256(bytes("Pegaxy|Vigorus")), getChainId(), address(this))
        );
    }

    function addSigner (address signer) public onlyRole(OWNER_ROLE) {
        require(signer != address(0), "Vigorus: signer is invalid");
        require(signers[signer] == false, "Vigorus: signer is exists");
        signers[signer] = true;

        emit SignerAdded(signer);
    }

    function removeSigner (address signer) public onlyRole(OWNER_ROLE) {
        require(signer != address(0), "Vigorus: signer is invalid");
        require(signers[signer] == true, "Vigorus: signer is not exists");
        signers[signer] = false;

        emit SignerRemoved(signer);
    }

    function mint(address account, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(account, amount);
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    function burnFor(uint256 amount, string memory reason) public {
        _burn(msg.sender, amount);
        emit BurnForReason(amount, reason);
    }

    function getClaimed(string memory txId) public view returns (uint256) {
        return claimTransactions[txId];
    }

    function claim(address player, string memory txId, uint256 amount, uint8 v, bytes32 r, bytes32 s) public {
        require(player != address(0), "Vigorus: Invalid claimer");
        require(amount > 0, "Vigorus: Invalid amount");

        bytes32 structHash = keccak256(abi.encode(CLAIM_TYPE_HASH, player, keccak256(bytes(txId)), amount));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        address signatory = ecrecover(digest, v, r, s);

        require(signers[signatory], "Vigorus: Signer is not valid");
        require(claimTransactions[txId] == 0, "Vigorus: transaction is claimed");

        claimTransactions[txId] = amount;

        _mint(player, amount);

        emit Claimed(player, txId, amount);
    }

    function getChainId() internal view returns (uint) {
        uint256 chainId;
        assembly { chainId := chainid() }
        return chainId;
    }
}