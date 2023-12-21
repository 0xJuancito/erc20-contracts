// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import "./IPlatform.sol";

interface IVolatilityToken {

    event Mint(uint256 requestId, address indexed account, uint256 tokenAmount, uint256 positionedTokenAmount, uint256 mintedTokens, uint256 openPositionFee, uint256 buyingPremiumFee);
    event Burn(uint256 requestId, address indexed account, uint256 tokenAmountBeforeFees, uint256 tokenAmount, uint256 burnedTokens, uint256 closePositionFee, uint256 closingPremiumFee);

    function mintTokensForOwner(address owner, uint168 tokenAmount, uint32 maxBuyingPremiumFeePercentage, uint32 realTimeCVIValue) external returns (uint256 tokensMinted);
    function burnTokensForOwner(address owner, uint168 burnAmount, uint32 realTimeCVIValue) external returns (uint256 tokensReceived);
    function mintTokens(uint168 tokenAmount, uint32 closeCVIValue, uint32 cviValue) external returns (uint256 tokensMinted);
    function burnTokens(uint168 burnAmount, uint32 cviValue) external returns (uint256 tokensReceived);

    function platform() external view returns (IPlatform);
    function leverage() external view returns (uint8);
    function initialTokenToLPTokenRate() external view returns (uint256);
}
