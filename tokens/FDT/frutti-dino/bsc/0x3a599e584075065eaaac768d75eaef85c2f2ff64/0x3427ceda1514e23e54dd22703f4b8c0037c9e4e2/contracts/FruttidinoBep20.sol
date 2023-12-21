// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "./interface/IERC1363.sol";
import "./interface/IERC1363Receiver.sol";
import "./interface/IERC1363Spender.sol";

contract FruttidinoBep20 is Initializable, ERC20BurnableUpgradeable,  AccessControlUpgradeable, ERC1363 {
    using AddressUpgradeable for address;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant LOCK_ROLE = keccak256("LOCK_ROLE");
    uint256 private _cap;
    mapping(address => uint256) _lock; // key : address, value: unix timestamp ( 10 length )

    function initialize(uint256 cap_, address admin, address minter) public initializer {
        require(cap_ > 0, "ERC20Capped: cap is 0");
        _cap = cap_;

        __ERC20_init("Frutti Dino", "FDT");
        __ERC20Burnable_init();
        __AccessControl_init();

        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(MINTER_ROLE, admin);
        _setupRole(LOCK_ROLE, admin);
        _setupRole(MINTER_ROLE, minter);

    }

    function _getTimestamp() internal view returns(uint256) {
        return block.timestamp;
    }

    function lock(address target, uint256 timestamp) public onlyRole(LOCK_ROLE) {
        require(timestamp > _getTimestamp(), "ER1");
        _lock[target] = timestamp;
    }

    function unlock(address target) public onlyRole(LOCK_ROLE) {
        _lock[target] = 0;
    }

    function isLock(address target) public view returns(bool) {
        return _lock[target] > _getTimestamp();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {

        uint256 lockTimestamp = _lock[from];
        require(lockTimestamp == 0 || lockTimestamp < _getTimestamp(), "Lock ERR");

        super._beforeTokenTransfer(from, to, amount);
    }

    function cap() public view returns (uint256) {
        return _cap;
    }

    function mint(address account, uint256 amount) public onlyRole(MINTER_ROLE) {
        require(ERC20Upgradeable.totalSupply() + amount <= cap(), "ERC20Capped: cap exceeded");
        super._mint(account, amount);
    }

    
    function transferAndCall(address to, uint256 amount) public virtual override returns (bool) {
        return transferAndCall(to, amount, "");
    }

    function transferAndCall(
        address to,
        uint256 amount,
        bytes memory data
    ) public virtual override returns (bool) {
        transfer(to, amount);
        require(_checkOnTransferReceived(_msgSender(), to, amount, data), "ERC1363: receiver returned wrong data");
        return true;
    }

    function transferFromAndCall(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        return transferFromAndCall(from, to, amount, "");
    }

    function transferFromAndCall(
        address from,
        address to,
        uint256 amount,
        bytes memory data
    ) public virtual override returns (bool) {
        transferFrom(from, to, amount);
        require(_checkOnTransferReceived(from, to, amount, data), "ERC1363: receiver returned wrong data");
        return true;
    }

    function approveAndCall(address spender, uint256 amount) public virtual override returns (bool) {
        return approveAndCall(spender, amount, "");
    }

  
    function approveAndCall(
        address spender,
        uint256 amount,
        bytes memory data
    ) public virtual override returns (bool) {
        approve(spender, amount);
        require(_checkOnApprovalReceived(spender, amount, data), "ERC1363: spender returned wrong data");
        return true;
    }


    function _checkOnTransferReceived(
        address sender,
        address recipient,
        uint256 amount,
        bytes memory data
    ) internal virtual returns (bool) {
        if (!recipient.isContract()) {
            revert("ERC1363: transfer to non contract address");
        }

        try ERC1363Receiver(recipient).onTransferReceived(_msgSender(), sender, amount, data) returns (bytes4 retval) {
            return retval == ERC1363Receiver.onTransferReceived.selector;
        } catch (bytes memory reason) {
            if (reason.length == 0) {
                revert("ERC1363: transfer to non ERC1363Receiver implementer");
            } else {
                /// @solidity memory-safe-assembly
                assembly {
                    revert(add(32, reason), mload(reason))
                }
            }
        }
    }


    function _checkOnApprovalReceived(
        address spender,
        uint256 amount,
        bytes memory data
    ) internal virtual returns (bool) {
        if (!spender.isContract()) {
            revert("ERC1363: approve a non contract address");
        }

        try ERC1363Spender(spender).onApprovalReceived(_msgSender(), amount, data) returns (bytes4 retval) {
            return retval == ERC1363Spender.onApprovalReceived.selector;
        } catch (bytes memory reason) {
            if (reason.length == 0) {
                revert("ERC1363: approve a non ERC1363Spender implementer");
            } else {
                /// @solidity memory-safe-assembly
                assembly {
                    revert(add(32, reason), mload(reason))
                }
            }
        }
    }

}
