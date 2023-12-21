pragma solidity ^0.6.0;

interface ICommonUtilities {
    function toString(address _addr) external pure returns(string memory);
    function toString(uint _i) external pure returns(string memory);
    function toUint256(bytes calldata bs) external pure returns(uint256 x);
    function toAddress(bytes calldata b) external pure returns (address addr);
    function compareStrings(string calldata a, string calldata b) external pure returns(bool);
    function getFirstJSONPart(address sourceLocation, uint256 sourceLocationId, address location) external pure returns(bytes memory);
    function formatReturnAbiParametersArray(string calldata m) external pure returns(string memory);
    function toLowerCase(string calldata str) external pure returns(string memory);
}