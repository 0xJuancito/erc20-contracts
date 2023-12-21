//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./abstract/BEP20.sol";
import "./interfaces/IAddressStore.sol";
import "./interfaces/IStakedBNBToken.sol";

/**
 * @dev {ERC777} token.
 *
 * The account that deploys the contract will be granted the BEP20 owner role.
 * The deployer can later transfer that role to a multi-sig, but the owner role can never be renounced.
 *
/**/

/// @custom:security-contact support@persistence.one
contract StakedBNBToken is IStakedBNBToken, ERC777, BEP20, Pausable {
    /*********************
     * STATE VARIABLES
     ********************/

    /**
     * @dev addressStore: The Address Store. Used to fetch addresses of the other contracts in the system.
     */
    IAddressStore private _addressStore;

    /*********************
     * ERRORS
     ********************/
    error UnauthorizedSender();

    /*********************
     * MODIFIERS
     ********************/

    modifier onlySender(address expectedSender) {
        _onlySender(expectedSender);
        _;
    }

    function _onlySender(address expectedSender) private view {
        if (msg.sender != expectedSender) {
            revert UnauthorizedSender();
        }
    }

    /*********************
     * CONTRACT LOGIC
     ********************/

    constructor(IAddressStore addressStore_)
        ERC777("Staked BNB", "stkBNB", new address[](0))
        BEP20(msg.sender) // Make the deployer the BEP20 owner, deployer will later transfer this role to a multi-sig.
    {
        _addressStore = addressStore_;
    }

    /**
     * @dev See {IERC777-totalSupply}.
     */
    function totalSupply() public view override(IERC777, ERC777) returns (uint256) {
        return ERC777.totalSupply();
    }

    /**
     * @dev Returns the amount of tokens owned by an account (`tokenHolder`).
     */
    function balanceOf(address tokenHolder)
        public
        view
        override(IERC777, ERC777)
        returns (uint256)
    {
        return ERC777.balanceOf(tokenHolder);
    }

    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC777-_burn}.
     *
     * Requirements:
     *
     * - the caller must be the StakePool contract.
     */
    function burn(uint256 amount, bytes memory data)
        public
        override(IERC777, ERC777)
        onlySender(_addressStore.getStakePool())
        whenNotPaused
    {
        ERC777.burn(amount, data);
    }

    /**
     * @dev See {IERC777-operatorBurn}.
     *
     * Emits {Burned} and {IERC20-Transfer} events.
     * Overridden to ensure that only the StakePool contract can call this.
     *
     * Requirements:
     *
     * - the caller must be the StakePool contract.
     */
    function operatorBurn(
        address account,
        uint256 amount,
        bytes memory data,
        bytes memory operatorData
    ) public override(IERC777, ERC777) onlySender(_addressStore.getStakePool()) whenNotPaused {
        ERC777.operatorBurn(account, amount, data, operatorData);
    }

    /**
     * @dev Creates `amount` new tokens for `account`.
     *
     * See {ERC777-_mint}.
     *
     * Requirements:
     *
     * - the caller must be the StakePool contract.
     */
    function mint(
        address account,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData
    ) external override onlySender(_addressStore.getStakePool()) whenNotPaused {
        ERC777._mint(account, amount, userData, operatorData);
    }

    /**
     * @dev pause: Used by admin to pause the contract.
     *             Supposed to be used in case of a prod disaster.
     *
     * Requirements:
     *
     * - The caller must be the owner.
     */
    function pause() external override onlyOwner {
        _pause();
    }

    /**
     * @dev unpause: Used by admin to resume the contract.
     *               Supposed to be used after the prod disaster has been mitigated successfully.
     *
     * Requirements:
     *
     * - The caller must be the owner.
     */
    function unpause() external override onlyOwner {
        _unpause();
    }

    /**
     * @dev selfDestruct
     *
     * The contract will be destroyed and BNB (if any) will be sent to the owner.
     *
     * This is supposed to be used only in case if tomorrow there arises a situation where
     * the token contract has to be taken down, eg: we are migrating to a breaking v2 of the
     * protocol, etc. then we would be able to do so.
     *
     * Requirements:
     *
     * - the caller must be the system's timelock controller.
     *
     */
    function selfDestruct()
        external
        override
        onlySender(_addressStore.getTimelockedAdmin())
        whenPaused
    {
        selfdestruct(payable(_owner));
    }

    /**
     * @return the address store
     */
    function addressStore() external view returns (IAddressStore) {
        return _addressStore;
    }
}
