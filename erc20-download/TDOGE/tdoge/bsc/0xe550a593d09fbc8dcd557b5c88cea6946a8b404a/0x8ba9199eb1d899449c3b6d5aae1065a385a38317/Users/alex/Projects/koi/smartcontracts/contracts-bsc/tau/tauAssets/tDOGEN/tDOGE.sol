// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;

import '../../tauElastic/v2/PlainElasticTokenWFixedRate.sol';

contract tDOGE is PlainElasticTokenWFixedRate{
    using SafeMathUpgradeable for uint256;
    uint8 public constant DEFAULT_DOGEN_DECIMALS = 8;
    function initialize() public initializer{
        super.initialize("τDogecoin","τDOGE");
        _setupDecimals(DEFAULT_DOGEN_DECIMALS);
    }
}