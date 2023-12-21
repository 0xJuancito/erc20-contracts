// SPDX-License-Identifier: MIT
// Unagi Contracts v1.0.0 (ChildChampToken.sol)
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./IChildToken.sol";

/**
 * @title Layer 2 ChampToken
 * @dev See ChampToken@0x456125Cd98107ae0480Ba566f1b716D48Ba31453
 * @custom:security-contact security@unagi.ch
 */
contract ChildChampToken is ERC777, IChildToken, AccessControl, Multicall {
    bytes32 public constant DEPOSITOR_ROLE = keccak256("DEPOSITOR_ROLE");

    constructor(address depositor)
        ERC777("Ultimate Champions Token", "CHAMP", new address[](0))
    {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(DEPOSITOR_ROLE, depositor);
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
        onlyRole(DEPOSITOR_ROLE)
    {
        uint256 amount = abi.decode(depositData, (uint256));
        _mint(user, amount, "", "");
    }

    /**
     * @notice called when user wants to withdraw tokens back to root chain
     * @dev Should burn user's tokens. This transaction will be verified when exiting on root chain
     * @param amount amount of tokens to withdraw
     */
    function withdraw(uint256 amount) external {
        _burn(_msgSender(), amount, "", "");
    }
}
