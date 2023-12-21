// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {OptimismMintableERC20} from "optimism-bedrock/universal/OptimismMintableERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 * @title MBSOptimismMintableERC20
 * @notice This contract is a variant of OptimismMintableERC20, incorporating permit functionality (ERC20Permit) and burnability (ERC20Burnable).
 *  It allows for a mintable, burnable ERC20 token with permit functionality on the Optimism network.
 *  This version of the token also enables the L2 Standard Bridge to burn tokens.
 */
contract MBSOptimismMintableERC20 is OptimismMintableERC20, ERC20Permit, ERC20Burnable {
    /**
     * @notice Constructs the MBSOptimismMintableERC20 contract with specified parameters.
     * @param _bridge The address of the L2 standard bridge, capable of minting and burning tokens.
     * @param _remoteToken The address of the corresponding L1 token.
     */
    constructor(address _bridge, address _remoteToken)
        OptimismMintableERC20(_bridge, _remoteToken, "MBS", "MBS")
        ERC20Permit("MBS")
    {}

    /**
     * @notice Overrides the burnFrom function from ERC20Burnable to facilitate token burning by the bridge.
     * @param _account The account from which tokens will be burned.
     * @param _amount The amount of tokens to burn.
     */
    function burnFrom(address _account, uint256 _amount) public virtual override {
        if (msg.sender == BRIDGE) {
            _burn(_account, _amount); // Direct burn if the caller is the bridge
        } else {
            ERC20Burnable.burnFrom(_account, _amount); // Otherwise, leverage the burnFrom method in ERC20Burnable
        }
    }
}
