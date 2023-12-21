pragma solidity 0.5.17;

/**
 * @title TokenVesting interface
 */
interface ITokenVesting {
  function beneficiary() external view returns (address);
}