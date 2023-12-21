pragma solidity ^0.5.16;

interface IManager {
    function userPermits(address user, string calldata permit) external view returns(bool);
    function guardian() external view returns(address);
    function inBlacklist(address[] calldata accounts) external view returns(bool);
    function protocolPaused() external view returns(bool);
    function redeemPaused() external view returns(bool);
    function repayPaused() external view returns(bool);
    function liquidatePaused() external view returns(bool);
    function transferDmTokenPaused() external view returns(bool);

    function marketMintPaused(address market) external view returns(bool);
    function marketBorrowPaused(address market) external view returns(bool);

    function mintVAIPaused() external view returns(bool);
    function repayVAIPaused() external view returns(bool);

    function dusdPaused() external view returns(bool);
    function dmtPaused() external view returns(bool);

    function members(string calldata mem) external view returns(address);
    function values(string calldata key) external view returns(uint256);
}