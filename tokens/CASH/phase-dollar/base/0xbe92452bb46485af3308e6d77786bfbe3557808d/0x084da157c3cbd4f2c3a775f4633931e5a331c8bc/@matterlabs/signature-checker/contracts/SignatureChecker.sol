pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";

library SignatureChecker {
    /** 
     * @dev Checks the signature of an account using ecrecover.
     * In the future, it will use EIP-1271 to validate signatures of AA contracts.
     */
    function isValidSignatureNow(
        address signer,
        bytes32 hash,
        bytes memory signature
    ) internal view returns (bool) {
        (address recovered, ECDSA.RecoverError error) = ECDSA.tryRecover(hash, signature);
        if (error == ECDSA.RecoverError.NoError && recovered == signer) {
            return true;
        }

        (bool success, bytes memory result) = signer.staticcall(
            abi.encodeWithSelector(IERC1271.isValidSignature.selector, hash, signature)
        );
        return (success &&
             result.length == 32 &&
             abi.decode(result, (bytes32)) == bytes32(IERC1271.isValidSignature.selector));
    }
}
