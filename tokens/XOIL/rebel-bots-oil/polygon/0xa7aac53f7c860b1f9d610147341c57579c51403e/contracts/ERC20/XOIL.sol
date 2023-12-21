/// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/interfaces/IERC1363Receiver.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title Rebel Bots Oil token (XOIL)
 *
 * @dev Token Summary:
 *      - Symbol: XOIL
 *      - Name: Rebel Bots Oil
 *      - Decimals: 8
 */
contract XOIL is AccessControl, ERC20Burnable {

    using Address for address;
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private admins;

    event TokenWithdrawn(address tokenContractAddress, uint256 amount);

    constructor() ERC20("Rebel Bots Oil", "XOIL") {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        admins.add(msg.sender);
    }


    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 8, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 8;
    }


    /**
     * @dev Transfer tokens to a specified address and then execute a callback on recipient.
     * @param recipient The address to transfer to
     * @param amount The amount to be transferred
     * @param data Additional data with no specified format
     * @return A boolean that indicates if the operation was successful.
     */
    function transferAndCall(address recipient, uint256 amount, bytes memory data) public virtual returns (bool) {
        transfer(recipient, amount);
        require(_checkAndCallTransfer(_msgSender(), recipient, amount, data), "ERC1363: _checkAndCallTransfer reverts");
        return true;
    }

    /**
  * @dev Transfer tokens from one address to another and then execute a callback on recipient.
     * @param sender The address which you want to send tokens from
     * @param recipient The address which you want to transfer to
     * @param amount The amount of tokens to be transferred
     * @param data Additional data with no specified format
     * @return A boolean that indicates if the operation was successful.
     */
    function transferFromAndCall(
        address sender,
        address recipient,
        uint256 amount,
        bytes memory data
    ) public virtual returns (bool) {
        transferFrom(sender, recipient, amount);
        require(_checkAndCallTransfer(sender, recipient, amount, data), "ERC1363: _checkAndCallTransfer reverts");
        return true;
    }

    /**
      * @dev Internal function to invoke `onTransferReceived` on a target address
     *  The call is not executed if the target address is not a contract
     * @param sender address Representing the previous owner of the given token value
     * @param recipient address Target address that will receive the tokens
     * @param amount uint256 The amount mount of tokens to be transferred
     * @param data bytes Optional data to send along with the call
     * @return whether the call correctly returned the expected magic value
     */
    function _checkAndCallTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bytes memory data
    ) internal virtual returns (bool) {
        if (!recipient.isContract()) {
            return false;
        }
        bytes4 retval = IERC1363Receiver(recipient).onTransferReceived(_msgSender(), sender, amount, data);
        return (retval == IERC1363Receiver(recipient).onTransferReceived.selector);
    }


    /**
     * @notice Minting tokens
     * @param user user for whom tokens are being minted
     * @param amount amount of token to mint
     */
    function mint(address user, uint256 amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _mint(user, amount);
    }

    /**
   *
   * @dev Allow owner to transfer ERC-20 token from contract
     *
     * @param tokenContract contract address of corresponding token
     * @param amount amount of token to be transferred
     *
     */
    function withdrawToken(address tokenContract, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(tokenContract).transfer(msg.sender, amount);
        emit TokenWithdrawn(tokenContract, amount);
    }

    function grantRole(bytes32 role, address account) public virtual override onlyRole(DEFAULT_ADMIN_ROLE) {
        super.grantRole(role, account);
        if (role == DEFAULT_ADMIN_ROLE) {
            admins.add(account);
        }
    }

    function revokeRole(bytes32 role, address account) public virtual override onlyRole(DEFAULT_ADMIN_ROLE) {
        super.revokeRole(role, account);
        if (role == DEFAULT_ADMIN_ROLE) {
            admins.remove(account);
        }
    }

    function renounceRole(bytes32 role, address account) public virtual override onlyRole(DEFAULT_ADMIN_ROLE) {
        super.renounceRole(role, account);
        if (role == DEFAULT_ADMIN_ROLE) {
            admins.remove(account);
        }
    }

    function getAdminCount() public view returns (uint256) {
        return admins.length();
    }

    function getAdmin(uint256 index) public view returns (address) {
        return admins.at(index);
    }
}