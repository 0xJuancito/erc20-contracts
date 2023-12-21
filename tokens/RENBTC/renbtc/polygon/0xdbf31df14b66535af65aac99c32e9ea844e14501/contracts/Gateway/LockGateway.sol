pragma solidity ^0.5.17;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/cryptography/ECDSA.sol";
import "@openzeppelin/upgrades/contracts/upgradeability/InitializableAdminUpgradeabilityProxy.sol";

import "../Governance/Claimable.sol";
import "../libraries/String.sol";
import "./RenERC20.sol";
import "./interfaces/IGateway.sol";
import "../libraries/CanReclaimTokens.sol";

contract LockGatewayStateV1 {
    uint256 constant BIPS_DENOMINATOR = 10000;
    uint256 public minimumBurnAmount;

    /// @notice Each Gateway is tied to a specific RenERC20 token.
    RenERC20LogicV1 public token;

    /// @notice The mintAuthority is an address that can sign mint requests.
    address public mintAuthority;

    /// @dev feeRecipient is assumed to be an address (or a contract) that can
    /// accept erc20 payments it cannot be 0x0.
    /// @notice When tokens are mint or burnt, a portion of the tokens are
    /// forwarded to a fee recipient.
    address public feeRecipient;

    /// @notice The mint fee in bips.
    uint16 public lockFee;

    /// @notice The burn fee in bips.
    uint16 public releaseFee;

    /// @notice Each signature can only be seen once.
    mapping(bytes32 => bool) public status;

    // LogMint and LogBurn contain a unique `n` that identifies
    // the mint or burn event.
    uint256 public nextN = 0;
}

/// @notice Gateway handles verifying mint and burn requests. A mintAuthority
/// approves new assets to be minted by providing a digital signature. An owner
/// of an asset can request for it to be burnt.
contract LockGatewayLogicV1 is
    Initializable,
    Claimable,
    CanReclaimTokens,
    // ILock,
    LockGatewayStateV1
{
    using SafeMath for uint256;

    event LogMintAuthorityUpdated(address indexed _newMintAuthority);
    event LogLock(
        bytes _to,
        bytes _p,
        uint256 _amount,
        uint256 indexed _n,
        bytes indexed _indexedTo
    );
    event LogRelease(
        address indexed _to,
        uint256 _amount,
        uint256 indexed _n,
        bytes32 indexed _signedMessageHash
    );

    /// @notice Only allow the Darknode Payment contract.
    modifier onlyOwnerOrMintAuthority() {
        require(
            msg.sender == mintAuthority || msg.sender == owner(),
            "Gateway: caller is not the owner or mint authority"
        );
        _;
    }

    /// @param _token The RenERC20 this Gateway is responsible for.
    /// @param _feeRecipient The recipient of burning and minting fees.
    /// @param _mintAuthority The address of the key that can sign mint
    ///        requests.
    /// @param _lockFee The amount subtracted each mint request and
    ///        forwarded to the feeRecipient. In BIPS.
    /// @param _releaseFee The amount subtracted each burn request and
    ///        forwarded to the feeRecipient. In BIPS.
    function initialize(
        RenERC20LogicV1 _token,
        address _feeRecipient,
        address _mintAuthority,
        uint16 _lockFee,
        uint16 _releaseFee,
        uint256 _minimumBurnAmount
    ) public initializer {
        Claimable.initialize(msg.sender);
        CanReclaimTokens.initialize(msg.sender);
        minimumBurnAmount = _minimumBurnAmount;
        token = _token;
        lockFee = _lockFee;
        releaseFee = _releaseFee;
        updateMintAuthority(_mintAuthority);
        updateFeeRecipient(_feeRecipient);
    }

    // Public functions ////////////////////////////////////////////////////////

    /// @notice Claims ownership of the token passed in to the constructor.
    /// `transferStoreOwnership` must have previously been called.
    /// Anyone can call this function.
    function claimTokenOwnership() public {
        token.claimOwnership();
    }

    /// @notice Allow the owner to update the fee recipient.
    ///
    /// @param _nextMintAuthority The address to start paying fees to.
    function updateMintAuthority(address _nextMintAuthority)
        public
        onlyOwnerOrMintAuthority
    {
        // The mint authority should not be set to 0, which is the result
        // returned by ecrecover for an invalid signature.
        require(
            _nextMintAuthority != address(0),
            "Gateway: mintAuthority cannot be set to address zero"
        );
        mintAuthority = _nextMintAuthority;
        emit LogMintAuthorityUpdated(mintAuthority);
    }

    /// @notice Allow the owner to update the fee recipient.
    ///
    /// @param _nextFeeRecipient The address to start paying fees to.
    function updateFeeRecipient(address _nextFeeRecipient) public onlyOwner {
        // 'mint' and 'burn' will fail if the feeRecipient is 0x0
        require(
            _nextFeeRecipient != address(0x0),
            "Gateway: fee recipient cannot be 0x0"
        );

        feeRecipient = _nextFeeRecipient;
    }

    /// @notice Allow the owner to update the 'mint' fee.
    ///
    /// @param _nextLockFee The new fee for locking.
    function updateLockFee(uint16 _nextLockFee) public onlyOwner {
        lockFee = _nextLockFee;
    }

    /// @notice Allow the owner to update the burn fee.
    ///
    /// @param _nextReleaseFee The new fee for releasing.
    function updateReleaseFee(uint16 _nextReleaseFee) public onlyOwner {
        releaseFee = _nextReleaseFee;
    }

    function lock(
        string memory _chain,
        bytes memory _to,
        bytes memory _payload,
        uint256 _amount
    ) public returns (uint256) {
        require(token.transferFrom(msg.sender, address(this), _amount));
        uint256 fee = _amount.mul(lockFee).div(BIPS_DENOMINATOR);
        token.transfer(feeRecipient, fee);
        uint256 amountAfterFee = _amount.sub(fee);
        emit LogLock(_to, _payload, amountAfterFee, nextN, _to);
        nextN += 1;
        return amountAfterFee;
    }

    /// @notice release verifies a release approval signature from RenVM and
    ///         sends tokens after taking a fee for the `_feeRecipient`.
    ///
    /// @param _pHash (payload hash) The hash of the payload associated with the
    ///        release.
    /// @param _amount The amount of the token being released, in its smallest
    ///        value. (e.g. satoshis for BTC).
    /// @param _nHash (nonce hash) The hash of the nonce, amount and pHash.
    /// @param _sig The signature of the hash of the following values:
    ///        (pHash, amount, msg.sender, nHash), signed by the mintAuthority.
    function release(
        bytes32 _pHash,
        uint256 _amount,
        bytes32 _nHash,
        bytes memory _sig
    ) public returns (uint256) {
        // Verify signature
        bytes32 signedMessageHash = hashForSignature(
            _pHash,
            _amount,
            msg.sender,
            _nHash
        );
        require(
            status[signedMessageHash] == false,
            "Gateway: nonce hash already spent"
        );
        if (!verifySignature(signedMessageHash, _sig)) {
            // Return a detailed string containing the hash and recovered
            // signer. This is somewhat costly but is only run in the revert
            // branch.
            revert(
                String.add8(
                    "Gateway: invalid signature. pHash: ",
                    String.fromBytes32(_pHash),
                    ", amount: ",
                    String.fromUint(_amount),
                    ", msg.sender: ",
                    String.fromAddress(msg.sender),
                    ", _nHash: ",
                    String.fromBytes32(_nHash)
                )
            );
        }
        status[signedMessageHash] = true;

        uint256 fee = _amount.mul(releaseFee).div(BIPS_DENOMINATOR);
        uint256 amountAfterFee = _amount.sub(fee);

        // Mint amount minus the fee
        token.transfer(msg.sender, fee);
        // Mint the fee
        token.transfer(feeRecipient, amountAfterFee);

        emit LogRelease(msg.sender, amountAfterFee, nextN, signedMessageHash);
        nextN += 1;

        return amountAfterFee;
    }

    /// @notice verifySignature checks the the provided signature matches the provided
    /// parameters.
    function verifySignature(bytes32 _signedMessageHash, bytes memory _sig)
        public
        view
        returns (bool)
    {
        return mintAuthority == ECDSA.recover(_signedMessageHash, _sig);
    }

    /// @notice hashForSignature hashes the parameters so that they can be signed.
    function hashForSignature(
        bytes32 _pHash,
        uint256 _amount,
        address _to,
        bytes32 _nHash
    ) public view returns (bytes32) {
        return
            keccak256(abi.encode(_pHash, _amount, address(token), _to, _nHash));
    }
}

/* solium-disable-next-line no-empty-blocks */
contract LockGatewayProxy is InitializableAdminUpgradeabilityProxy {

}
