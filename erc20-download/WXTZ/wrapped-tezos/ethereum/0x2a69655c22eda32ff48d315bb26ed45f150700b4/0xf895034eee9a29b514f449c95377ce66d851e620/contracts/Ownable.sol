pragma solidity 0.5.13;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/GSN/Context.sol";

/**
 * @dev This contract is analogous to the one in @openzeppelin/contracts
 * (most of the code is taken from there). However, it provides a two-step
 * ownership transfer to guarantee that the new owner exists and posesses
 * the private key from his account.
 */
contract Ownable is Initializable, Context {
    address private _owner;
    address private _pendingOwner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function initialize(address sender) public initializer {
        _owner = sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Returns the address of the pending owner.
     */
    function pendingOwner() public view returns (address) {
        return _pendingOwner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Returns true if the caller is the current owner.
     */
    function isOwner() public view returns (bool) {
        return _msgSender() == _owner;
    }

    /**
     * @dev Returns true if the caller is the pending owner.
     */
    function isPendingOwner() public view returns (bool) {
        return _msgSender() == _pendingOwner;
    }

    /**
     * @dev Updates the `_pendingOwner`. After `_pendingOwner` accepts the
     * transfer using `acceptOwnership`, the `_owner` gets updated. Until
     * then, the current owner holds the ownership.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _pendingOwner = newOwner;
    }

    /**
     * @dev Makes _pendingOwner accept the ownership, i.e. become
     * the new `_owner`. The old `_owner` loses his rights.
     */
    function acceptOwnership() public {
        require(
            _pendingOwner == _msgSender(),
            "Ownable: caller is not the pending owner"
        );
        emit OwnershipTransferred(_owner, _pendingOwner);
        _owner = _pendingOwner;
        _pendingOwner = address(0);
    }

    uint256[50] private ______gap;
}
