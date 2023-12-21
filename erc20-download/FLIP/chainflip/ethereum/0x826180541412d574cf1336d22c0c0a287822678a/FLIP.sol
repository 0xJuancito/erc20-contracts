// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "ERC20.sol";
import "IFLIP.sol";
import "Shared.sol";

/**
 * @title    FLIP contract
 * @notice   The FLIP utility token which is used in the StateChain.
 */
contract FLIP is ERC20, IFLIP, Shared {
    address private issuer;

    constructor(
        uint256 flipTotalSupply,
        uint256 numGenesisValidators,
        uint256 genesisStake,
        address receiverGenesisValidatorFlip, // StateChainGateway
        address receiverGenesisFlip,
        address genesisIssuer //StateChainGateway
    )
        ERC20("Chainflip", "FLIP")
        nzAddr(receiverGenesisValidatorFlip)
        nzAddr(receiverGenesisFlip)
        nzUint(flipTotalSupply)
        nzAddr(genesisIssuer)
    {
        uint256 genesisValidatorFlip = numGenesisValidators * genesisStake;
        _mint(receiverGenesisValidatorFlip, genesisValidatorFlip);
        _mint(receiverGenesisFlip, flipTotalSupply - genesisValidatorFlip);
        issuer = genesisIssuer;
    }

    //////////////////////////////////////////////////////////////
    //                                                          //
    //                  State-changing functions                //
    //                                                          //
    //////////////////////////////////////////////////////////////

    /**
     * @notice Mint FLIP tokens to an account. This is controlled via an issuer
     *         controlled by the StateChain to adjust the supply of FLIP tokens.
     * @dev    The _mint function checks for zero address. We do not check for
     *         zero amount because there is no real reason to revert and we want
     *         to minimise reversion of State Chain calls
     * @param account   Account to receive the newly minted tokens
     * @param amount    Amount of tokens to mint
     */
    function mint(address account, uint amount) external override onlyIssuer {
        _mint(account, amount);
    }

    /**
     * @notice Mint FLIP tokens to an account. This is controlled via an issuer
     *         controlled by the StateChain to adjust the supply of FLIP tokens.
     * @dev    The _burn function checks for zero address. We do not check for
     *         zero amount because there is no real reason to revert and we want
     *         to minimise reversion of State Chain calls.
     * @param account   Account to burn the tokens from
     * @param amount    Amount of tokens to burn
     */
    function burn(address account, uint amount) external override onlyIssuer {
        _burn(account, amount);
    }

    /**
     * @notice Update the issuer address. This is to be controlled via an issuer
     *         controlled by the StateChain.
     * @param newIssuer   Account that can mint and burn FLIP tokens.
     */
    function updateIssuer(address newIssuer) external override nzAddr(issuer) onlyIssuer {
        emit IssuerUpdated(issuer, newIssuer);
        issuer = newIssuer;
    }

    //////////////////////////////////////////////////////////////
    //                                                          //
    //                  Non-state-changing functions            //
    //                                                          //
    //////////////////////////////////////////////////////////////

    /// @dev Get the issuer address.
    function getIssuer() external view override returns (address) {
        return issuer;
    }

    //////////////////////////////////////////////////////////////
    //                                                          //
    //                        Modifiers                         //
    //                                                          //
    //////////////////////////////////////////////////////////////

    /// @dev    Check that the caller is the token issuer.
    modifier onlyIssuer() {
        require(msg.sender == issuer, "FLIP: not issuer");
        _;
    }
}
