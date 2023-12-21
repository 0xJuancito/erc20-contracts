// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.11;

import "../lib/MerkleProof.sol";
import "../eip/interface/IERC20.sol";

abstract contract TokenMigrateERC20 {
    /// @dev The sender is not authorized to perform the action
    error TokenMigrateUnauthorized();

    /// @dev Invalid proofs to claim the token ownership for id
    error TokenMigrateInvalidProof(address owner, uint256 maxQuantity);

    /// @dev Token is already migrated
    error TokenMigrateAlreadyMigrated(address owner, uint256 maxQuantity);

    /*///////////////////////////////////////////////////////////////
                            State Variables
    //////////////////////////////////////////////////////////////*/

    /// @notice The merkle root contianing token ownership information.
    bytes32 private ownershipMerkleRoot;

    /// @notice The address of the original token contract.
    address internal _originalContract;

    /// @notice A mapping from ownership id to the amount claimed.
    mapping(address => uint256) private _amountClaimed;

    /*///////////////////////////////////////////////////////////////
                        External/Public Functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Migrates tokens via proving inclusion in the merkle root.
    /// @dev Assumption: tokens on the original contract are non-transferrable.
    function migrate(address _tokenOwner, uint256 _proofMaxQuantity, bytes32[] calldata _proof) external {
        address id = _tokenOwner;
        // Check if the total tokens owed have not already been claimed
        if (_amountClaimed[id] >= _proofMaxQuantity) {
            revert TokenMigrateAlreadyMigrated(_tokenOwner, _proofMaxQuantity);
        }

        if (_requireVerification()) {
            // Verify that the proof is valid
            bool isValidProof;
            (isValidProof, ) = MerkleProof.verify(
                _proof,
                _merkleRoot(),
                keccak256(abi.encodePacked(_tokenOwner, _proofMaxQuantity))
            );
            if (!isValidProof) {
                revert TokenMigrateInvalidProof(_tokenOwner, _proofMaxQuantity);
            }
        }

        // Send the difference to the token owner
        uint256 _amount = _proofMaxQuantity - _amountClaimed[id];
        // Mark token ownership as claimed
        _amountClaimed[id] = _proofMaxQuantity;

        // Mint token to token owner
        _mintMigratedTokens(_tokenOwner, _amount);
    }

    /// @notice Sets the merkle root containing token ownership information.
    function setMerkleRoot(bytes32 _merkleRoot) external virtual {
        if (!_canSetMerkleRoot()) {
            revert TokenMigrateUnauthorized();
        }
        _setupMerkleRoot(_merkleRoot);
    }

    /*///////////////////////////////////////////////////////////////
                        Internal Functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the merkle root containing token ownership information.
    function _merkleRoot() internal view virtual returns (bytes32) {
        return ownershipMerkleRoot;
    }

    /// @notice Sets up the original token contract address.
    function _setupOriginalContract(address __originalContract) internal virtual {
        _originalContract = __originalContract;
    }

    /// @notice Sets up the merkle root containing token ownership information.
    function _setupMerkleRoot(bytes32 _merkleRoot) internal virtual {
        ownershipMerkleRoot = _merkleRoot;
    }

    /*///////////////////////////////////////////////////////////////
                        Unimplemented Functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Mints migrated token to token owner.
    function _mintMigratedTokens(address _tokenOwner, uint256 _amount) internal virtual;

    /// @notice Returns whether merkle root can be set in the given execution context.
    function _canSetMerkleRoot() internal virtual returns (bool);

    /// @notice Returns whether the caller address needs to be verified.
    function _requireVerification() internal virtual returns (bool);
}
