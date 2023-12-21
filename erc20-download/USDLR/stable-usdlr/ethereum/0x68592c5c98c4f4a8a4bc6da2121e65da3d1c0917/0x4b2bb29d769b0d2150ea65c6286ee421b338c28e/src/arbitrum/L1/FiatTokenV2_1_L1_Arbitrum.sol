// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "openzeppelin/token/ERC20/IERC20.sol";

import {FiatTokenV2_1} from "../../v2/FiatTokenV2_1.sol";
import {ICustomToken} from "./ICustomToken.sol";

interface IL1CustomGateway {
    function registerTokenToL2(
        address _l2Address,
        uint256 _maxGas,
        uint256 _gasPriceBid,
        uint256 _maxSubmissionCost,
        address _creditBackAddress
    ) external payable returns (uint256);
}

interface IGatewayRouter2 {
    function setGateway(
        address _gateway,
        uint256 _maxGas,
        uint256 _gasPriceBid,
        uint256 _maxSubmissionCost,
        address _creditBackAddress
    ) external payable returns (uint256);
}

contract FiatTokenV2_1_L1_Arbitrum is FiatTokenV2_1, ICustomToken {
    /// @notice should return `0xb1` if token is enabled for arbitrum gateways
    /// @dev Previous implmentation used to return `uint8(0xa4b1)`, however that causes compile time error in Solidity 0.8. due to type mismatch.
    ///      In current version `uint8(0xb1)` shall be returned, which results in no change as that's the same value as truncated `uint8(0xa4b1)`.
    function isArbitrumEnabled() external pure returns (uint8) {
        return uint8(0xb1);
    }

    /**
     * @notice Should make an external call to EthERC20Bridge.registerCustomL2Token
     */
    function registerTokenOnL2(
        address l2CustomTokenAddress,
        uint256 maxSubmissionCostForCustomGateway,
        uint256 maxSubmissionCostForRouter,
        uint256 maxGasForCustomGateway,
        uint256 maxGasForRouter,
        uint256 gasPriceBid,
        uint256 valueForGateway,
        uint256 valueForRouter,
        address creditBackAddress
    ) external payable {
        // TODO update and double check addresses before upgrading
        // currently for sepolia

        //gateway address
        IL1CustomGateway(0xcEe284F754E854890e311e3280b767F80797180d)
            .registerTokenToL2{value: valueForGateway}(
            l2CustomTokenAddress,
            maxGasForCustomGateway,
            gasPriceBid,
            maxSubmissionCostForCustomGateway,
            creditBackAddress
        );

        //router address
        IGatewayRouter2(0x72Ce9c846789fdB6fC1f34aC4AD25Dd9ef7031ef).setGateway{
            value: valueForRouter
        }(
            //gateway address
            0xcEe284F754E854890e311e3280b767F80797180d,
            maxGasForRouter,
            gasPriceBid,
            maxSubmissionCostForRouter,
            creditBackAddress
        );
    }
}
