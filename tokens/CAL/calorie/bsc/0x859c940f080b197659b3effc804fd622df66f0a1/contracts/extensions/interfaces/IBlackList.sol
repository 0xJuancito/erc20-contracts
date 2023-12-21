// SPDX-License-Identifier: UNLICENSED

// Author: TrejGun
// Email: trejgun@gemunion.io
// Website: https://gemunion.io/

pragma solidity ^0.8.13;

interface IBlackList {
  error BlackListError(address account);

  event Blacklisted(address indexed account);
  event UnBlacklisted(address indexed account);

  function blacklist(address account) external;

  function unBlacklist(address account) external;

  function isBlacklisted(address account) external view returns (bool);
}
