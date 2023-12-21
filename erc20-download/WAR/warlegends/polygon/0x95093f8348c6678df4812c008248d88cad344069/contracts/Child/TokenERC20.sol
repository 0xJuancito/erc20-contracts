// SPDX-License-Identifier: Playchain
pragma solidity 0.8.13;

import "../CommonERC20.sol";


contract ChildTokenERC20 is CommonERC20 {

    bytes32 public constant DEPOSITOR_ROLE = keccak256("DEPOSITOR_ROLE");

    constructor(string memory name, string memory symbol, address childChainManager) CommonERC20(name, symbol) {
        _setupRole(DEPOSITOR_ROLE, childChainManager);
        _mint(_msgSender(), 35 * (10**25));
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
        only(DEPOSITOR_ROLE)
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

    /**
     * @dev Minting can be done as per requirement
     * @param user user for whom tokens are being minted
     * @param amount amount of token to mint
     */
    function mint(address user, uint256 amount) public only(MINTER_ROLE) {
        _mint(user, amount);
    }
}
