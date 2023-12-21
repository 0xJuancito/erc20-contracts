// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import {AccessControlMixin} from "./external/common/AccessControlMixin.sol"; // inherits openzepellin AccessControl
import {IChildToken} from "./external/interfaces/IChildToken.sol";
import {NativeMetaTransaction} from "./external/common/NativeMetaTransaction.sol";
import {ContextMixin} from "./external/common/ContextMixin.sol";

contract ChildFaithTribe is ERC20Snapshot, AccessControlMixin, IChildToken, NativeMetaTransaction, ContextMixin {

    bytes32 private constant SNAPSHOT_ROLE = keccak256("SNAPSHOT_ROLE");
    bytes32 private constant DEPOSITER_ROLE = keccak256("DEPOSITER_ROLE");

    constructor(string memory name_, string memory symbol_, address snapshotRole, address childChainManager) ERC20(name_, symbol_) {
        _setupRole(SNAPSHOT_ROLE, snapshotRole);
        _setupRole(DEPOSITER_ROLE, childChainManager);
        _setupContractId("ChildFaithTribe");
        _initializeEIP712(name_);
    }

    // This is to support Native meta transactions
    // never use msg.sender directly, use _msgSender() instead
    function _msgSender()
        internal
        override
        view
        returns (address sender)
    {
        return ContextMixin.msgSender();
    }

    /**
     * @notice called when token is deposited on root chain
     * @dev Should be callable only by ChildChainManager
     * Should handle deposit by minting the required amount for user
     * Make sure minting is done only by this function
     * @param user user address for whom deposit is being done
     * @param depositData abi encoded amount
     */
    function deposit(address user, bytes calldata depositData)
        external
        override
        onlyRole(DEPOSITER_ROLE)
    {
        uint256 amount = abi.decode(depositData, (uint256));
        _mint(user, amount);
    }

    /**
     * @notice called when user wants to withdraw tokens back to root chain
     * @dev Should burn user's tokens. This transaction will be verified when exiting on root chain
     * @param amount amount of tokens to withdraw
     */
    function withdraw(uint256 amount) external {
        _burn(_msgSender(), amount);
    }

    function snapshot() public onlyRole(SNAPSHOT_ROLE) {
        _snapshot();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20Snapshot)
    {
        super._beforeTokenTransfer(from, to, amount);
    }
}