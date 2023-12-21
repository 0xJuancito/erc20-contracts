pragma solidity ^0.6.2;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/GSN/GSNRecipientUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC777/ERC777Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract ERC777GSNUpgreadable is Initializable, OwnableUpgradeable, GSNRecipientUpgradeable, ERC777Upgradeable {
  using ECDSAUpgradeable for bytes32;
  uint256 constant GSN_RATE_UNIT = 10**18;

  enum GSNErrorCodes {
    INVALID_SIGNER,
    INSUFFICIENT_BALANCE
  }

  address public gsnTrustedSigner;
  address public gsnFeeTarget;
  uint256 public gsnExtraGas; // the gas cost of _postRelayedCall()

  function __ERC777GSNUpgreadable_init(
    address _gsnTrustedSigner,
    address _gsnFeeTarget
  )
    public
    initializer
  {
    __GSNRecipient_init();
    __Ownable_init();

    require(_gsnTrustedSigner != address(0), "trusted signer is the zero address");
    gsnTrustedSigner = _gsnTrustedSigner;

    require(_gsnFeeTarget != address(0), "fee target is the zero address");
    gsnFeeTarget = _gsnFeeTarget;
    gsnExtraGas = 40000;
  }

  function _msgSender() internal view virtual override(ContextUpgradeable, GSNRecipientUpgradeable) returns (address payable) {
    return GSNRecipientUpgradeable._msgSender();
  }

  function _msgData() internal view virtual override(ContextUpgradeable, GSNRecipientUpgradeable) returns (bytes memory) {
    return GSNRecipientUpgradeable._msgData();
  }


  function setTrustedSigner(address _gsnTrustedSigner) public onlyOwner {
    require(_gsnTrustedSigner != address(0), "trusted signer is the zero address");
    gsnTrustedSigner = _gsnTrustedSigner;
  }

  function setFeeTarget(address _gsnFeeTarget) public onlyOwner {
    require(_gsnFeeTarget != address(0), "fee target is the zero address");
    gsnFeeTarget = _gsnFeeTarget;
  }

  function setGSNExtraGas(uint _gsnExtraGas) public onlyOwner {
    gsnExtraGas = _gsnExtraGas;
  }


  /**
 * @dev Ensures that only transactions with a trusted signature can be relayed through the GSN.
 */
  function acceptRelayedCall(
    address relay,
    address from,
    bytes memory encodedFunction,
    uint256 transactionFee,
    uint256 gasPrice,
    uint256 gasLimit,
    uint256 nonce,
    bytes memory approvalData,
    uint256 /* maxPossibleCharge */
  )
    override
    public
    view
    returns (uint256, bytes memory)
  {
    (uint256 feeRate, bytes memory signature) = abi.decode(approvalData, (uint, bytes));
    bytes memory blob = abi.encodePacked(
      feeRate,
      relay,
      from,
      encodedFunction,
      transactionFee,
      gasPrice,
      gasLimit,
      nonce, // Prevents replays on RelayHub
      getHubAddr(), // Prevents replays in multiple RelayHubs
      address(this) // Prevents replays in multiple recipients
    );
    if (keccak256(blob).toEthSignedMessageHash().recover(signature) == gsnTrustedSigner) {
      return _approveRelayedCall(abi.encode(feeRate, from, transactionFee, gasPrice));
    } else {
      return _rejectRelayedCall(uint256(GSNErrorCodes.INVALID_SIGNER));
    }
  }

  function _preRelayedCall(bytes memory context) override internal returns (bytes32) {}

  function _postRelayedCall(bytes memory context, bool, uint256 actualCharge, bytes32) override internal {
    (uint256 feeRate, address from, uint256 transactionFee, uint256 gasPrice) =
      abi.decode(context, (uint256, address, uint256, uint256));

    // actualCharge is an _estimated_ charge, which assumes postRelayedCall will use all available gas.
    // This implementation's gas cost can be roughly estimated as 10k gas, for the two SSTORE operations in an
    // ERC20 transfer.
    uint256 overestimation = _computeCharge(_POST_RELAYED_CALL_MAX_GAS.sub(gsnExtraGas), gasPrice, transactionFee);
    uint fee = actualCharge.sub(overestimation).mul(feeRate).div(GSN_RATE_UNIT);

    if (fee > 0) {
      _send(from, gsnFeeTarget, fee, "", "", false);
    }
  }
}
