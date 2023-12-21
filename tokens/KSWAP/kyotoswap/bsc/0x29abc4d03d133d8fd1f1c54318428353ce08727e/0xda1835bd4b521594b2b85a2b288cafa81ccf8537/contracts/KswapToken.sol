// SPDX-License-Identifier: MIT

////////////////////////////////////////////////solarde.fi//////////////////////////////////////////////
//_____/\\\\\\\\\\\_________/\\\\\_______/\\\_________________/\\\\\\\\\_______/\\\\\\\\\_____        //
// ___/\\\/////////\\\_____/\\\///\\\____\/\\\_______________/\\\\\\\\\\\\\___/\\\///////\\\___       //
//  __\//\\\______\///____/\\\/__\///\\\__\/\\\______________/\\\/////////\\\_\/\\\_____\/\\\___      //
//   ___\////\\\__________/\\\______\//\\\_\/\\\_____________\/\\\_______\/\\\_\/\\\\\\\\\\\/____     //
//    ______\////\\\______\/\\\_______\/\\\_\/\\\_____________\/\\\\\\\\\\\\\\\_\/\\\//////\\\____    //
//     _________\////\\\___\//\\\______/\\\__\/\\\_____________\/\\\/////////\\\_\/\\\____\//\\\___   //
//      __/\\\______\//\\\___\///\\\__/\\\____\/\\\_____________\/\\\_______\/\\\_\/\\\_____\//\\\__  //
//       _\///\\\\\\\\\\\/______\///\\\\\/_____\/\\\\\\\\\\\\\\\_\/\\\_______\/\\\_\/\\\______\//\\\_ //
//        ___\///////////__________\/////_______\///////////////__\///________\///__\///________\///__//
////////////////////////////////////////////////////////////////////////////////////////////////////////

pragma solidity ^0.8.9;

import {IERC20Mintable} from "./interfaces/IERC20Mintable.sol";
import {Initializer} from "@solarprotocol/solidity-modules/contracts/modules/utils/initializer/Initializer.sol";
import {ERC20Facet, LibERC20} from "@solarprotocol/solidity-modules/contracts/modules/token/ERC20/facets/ERC20Facet.sol";
import {AccessControlFacet, LibAccessControl} from "@solarprotocol/solidity-modules/contracts/modules/access/AccessControlFacet.sol";
import {LibRoles} from "@solarprotocol/solidity-modules/contracts/modules/access/LibRoles.sol";
import {PausableFacet, LibPausable} from "@solarprotocol/solidity-modules/contracts/modules/pausable/PausableFacet.sol";
import {SimpleBlacklistFacet} from "@solarprotocol/solidity-modules/contracts/modules/blacklist/SimpleBlacklistFacet.sol";

contract KswapToken is
    IERC20Mintable,
    Initializer,
    ERC20Facet,
    AccessControlFacet,
    PausableFacet,
    SimpleBlacklistFacet
{
    bytes32 public constant MINTER_ROLE = keccak256("ERC20_MINTER_ROLE");

    function mint(address account, uint256 amount) external {
        LibAccessControl.enforceRole(MINTER_ROLE);

        LibERC20.mint(account, amount);
    }

    function initialize(
        address owner,
        address[] memory mints,
        uint256[] memory mintAmounts
    ) external initializer {
        LibERC20.setName("KyotoSwap Token");
        LibERC20.setSymbol("KSWAP");

        LibAccessControl.setRoleAdmin(MINTER_ROLE, LibRoles.MANAGER_ROLE);
        LibAccessControl.grantRole(LibRoles.DEFAULT_ADMIN_ROLE, owner);
        LibAccessControl.grantRole(LibRoles.MANAGER_ROLE, owner);
        LibAccessControl.grantRole(LibRoles.MANAGER_ROLE, msg.sender);

        LibPausable.unpause();

        for (uint256 index = 0; index < mints.length; ++index) {
            LibERC20.mint(mints[index], mintAmounts[index]);
        }
    }
}
