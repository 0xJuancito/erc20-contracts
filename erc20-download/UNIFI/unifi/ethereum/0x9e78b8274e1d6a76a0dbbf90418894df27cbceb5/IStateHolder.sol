pragma solidity ^0.6.0;

interface IStateHolder {

    function init() external;

    function getProxy() external view returns (address);
    function setProxy() external;
    function toJSON() external view returns(string memory);
    function toJSON(uint256 start, uint256 l) external view returns(string memory);
    function getStateSize() external view returns (uint256);
    function exists(string calldata varName) external view returns(bool);
    function getDataType(string calldata varName) external view returns(string memory dataType);
    function clear(string calldata varName) external returns(string memory oldDataType, bytes memory oldVal);
    function setBytes(string calldata varName, bytes calldata val) external returns(bytes memory);
    function getBytes(string calldata varName) external view returns(bytes memory);
    function setString(string calldata varName, string calldata val) external returns(string memory);
    function getString(string calldata varName) external view returns (string memory);
    function setBool(string calldata varName, bool val) external returns(bool);
    function getBool(string calldata varName) external view returns (bool);
    function getUint256(string calldata varName) external view returns (uint256);
    function setUint256(string calldata varName, uint256 val) external returns(uint256);
    function getAddress(string calldata varName) external view returns (address);
    function setAddress(string calldata varName, address val) external returns (address);
}