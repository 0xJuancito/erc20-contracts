// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/proxy/Initializable.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract OwnableWithAccept is Context, Initializable {
    address private _owner;
    address private _nextOwner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function initializeOwner() public initializer {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        initializeOwner();
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev set the next owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _nextOwner = newOwner;
    }

    /**
     * @dev the next owner must call this function to accept the ownership
     */
    function acceptOwnership() public virtual {
        require(_msgSender() == _nextOwner, "you are not next owner");
        emit OwnershipTransferred(_owner, _nextOwner);
        _owner = _nextOwner;
        _nextOwner = address(0);
    }

    /**
     * @dev Get next owner and only current owner or next owner himself can see it.
     */
    function getNextOwner() public view returns (address) {
        if (_msgSender() == _nextOwner || _msgSender() == owner()) {
            return _nextOwner;
        }
        return address(0);
    }
}
