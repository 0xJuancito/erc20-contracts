// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ABaseDiamond} from "@lib-diamond/src/diamond/ABaseDiamond.sol";
import {LibDiamond} from "@lib-diamond/src/diamond/LibDiamond.sol";
import {DiamondStorage} from "@lib-diamond/src/diamond/DiamondStorage.sol";
import {IDiamondCut} from "@lib-diamond/src/diamond/IDiamondCut.sol";
import {IDiamondLoupe} from "@lib-diamond/src/diamond/IDiamondLoupe.sol";
import {FacetCut, FacetCutAction} from "@lib-diamond/src/diamond/Facet.sol";
import {DiamondCutAndLoupeFacet} from "./facets/DiamondCutAndLoupeFacet.sol";

import {AccessControlEnumerableStorage} from "@lib-diamond/src/access/access-control/AccessControlEnumerableStorage.sol";
import {DEFAULT_ADMIN_ROLE} from "@lib-diamond/src/access/access-control/Roles.sol";
import {LibAccessControlEnumerable} from "@lib-diamond/src/access/access-control/LibAccessControlEnumerable.sol";
import {WithRoles} from "@lib-diamond/src/access/access-control/WithRoles.sol";
import {IAccessControl} from "@lib-diamond/src/access/access-control/IAccessControl.sol";
import {IAccessControlEnumerable} from "@lib-diamond/src/access/access-control/IAccessControlEnumerable.sol";
import {AccessControlEnumerableFacet} from "@lib-diamond/src/access/access-control/AccessControlEnumerableFacet.sol";

import {ERC165Facet} from "@lib-diamond/src/utils/introspection/erc165/ERC165Facet.sol";

import {LibHamachi} from "./libraries/LibHamachi.sol";
import {HamachiStorage} from "./types/hamachi/HamachiStorage.sol";
import {LibReward} from "./libraries/LibReward.sol";
import {RewardStorage} from "./types/reward/RewardStorage.sol";
import {LibUniswap} from "./libraries/LibUniswap.sol";
import {UniswapStorage} from "./types/uniswap/UniswapStorage.sol";


import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

import {Proxy} from "@lib-diamond/src/proxy-etherscan/Proxy.sol";

contract Diamond is ABaseDiamond, WithRoles, Proxy {
  constructor(
    address liquidityWallet,
    address defaultRouter,
    address defaultPair,
    address contractAdmin,
    address diamondCutAndLoupeFacet_,
    address accessControlEnumerableFacet_,
    address erc165Facet_,
    address methodsExposureFacetAddress_
  ) payable {
    LibAccessControlEnumerable.grantRole(DEFAULT_ADMIN_ROLE, contractAdmin);

    HamachiStorage storage hs = LibHamachi.DS();
    RewardStorage storage rs = LibReward.DS();
    UniswapStorage storage us = LibUniswap.DS();

    hs.fee.liquidityBuyFee = 100;
    hs.fee.rewardBuyFee = 600;

    hs.fee.liquiditySellFee = 100;
    hs.fee.rewardSellFee = 600;

    hs.numTokensToSwap = 10_000_000 * 10 ** 18;
    hs.maxTokenPerWallet = 250_000_000 * 10 ** 18; // Max holding limit, 0.25% of supply
    hs.swapRouters[defaultRouter] = true;

    us.defaultRouter = defaultRouter;
    us.liquidityWallet = liquidityWallet;

    hs.processingGas = 750_000;
    hs.processingFees = false;
    hs.processRewards = true;

    rs.minRewardBalance = 1000 * 10 ** 18;
    rs.claimTimeout = 3600;

    _setImplementation(methodsExposureFacetAddress_);

    rs.rewardToken.token = address(0xB64E280e9D1B5DbEc4AcceDb2257A87b400DB149);
    rs.rewardToken.router = defaultRouter;
    rs.rewardToken.path = [defaultPair, address(this)];

    rs.goHam.token = address(this);
    rs.goHam.router = defaultRouter;
    rs.goHam.path = [defaultPair, address(this)];

    IUniswapV2Router02 router = IUniswapV2Router02(defaultRouter);
    address swapPair = IUniswapV2Factory(router.factory()).createPair(address(this), defaultPair);
    hs.lpPools[address(swapPair)] = true;

    // Add the diamondCut external function from the diamondCutFacet
    FacetCut[] memory cut;
    bytes4[] memory functionSelectors;

    // Add the diamondLoupe external functions from the diamondLoupeFacet
    cut = new FacetCut[](1);
    functionSelectors = new bytes4[](5);
    functionSelectors[0] = IDiamondCut.diamondCut.selector;
    functionSelectors[1] = IDiamondLoupe.facets.selector;
    functionSelectors[2] = IDiamondLoupe.facetFunctionSelectors.selector;
    functionSelectors[3] = IDiamondLoupe.facetAddresses.selector;
    functionSelectors[4] = IDiamondLoupe.facetAddress.selector;
    cut[0] = FacetCut({
      facetAddress: diamondCutAndLoupeFacet_,
      action: FacetCutAction.Add,
      functionSelectors: functionSelectors
    });
    LibDiamond.diamondCut(cut, address(0), "");

    // Add the access control external functions from the AccessControlEnumerableFacet
    cut = new FacetCut[](1);
    functionSelectors = new bytes4[](8);
    functionSelectors[0] = IAccessControl.hasRole.selector;
    functionSelectors[1] = IAccessControl.getRoleAdmin.selector;
    functionSelectors[2] = IAccessControl.grantRole.selector;
    functionSelectors[3] = IAccessControl.revokeRole.selector;
    functionSelectors[4] = IAccessControl.renounceRole.selector;
    functionSelectors[5] = AccessControlEnumerableFacet.getRoleMember.selector;
    functionSelectors[6] = AccessControlEnumerableFacet.getRoleMemberCount.selector;
    functionSelectors[7] = AccessControlEnumerableFacet.getRoleMembers.selector;
    cut[0] = FacetCut({
      facetAddress: accessControlEnumerableFacet_,
      action: FacetCutAction.Add,
      functionSelectors: functionSelectors
    });
    LibDiamond.diamondCut(cut, address(0), "");

    // Add the ERC165 external functions from the erc165Facet
    cut = new FacetCut[](1);
    functionSelectors = new bytes4[](1);
    functionSelectors[0] = ERC165Facet.supportsInterface.selector;
    cut[0] = FacetCut({
      facetAddress: erc165Facet_,
      action: FacetCutAction.Add,
      functionSelectors: functionSelectors
    });
    LibDiamond.diamondCut(cut, address(0), "");
  }
}
