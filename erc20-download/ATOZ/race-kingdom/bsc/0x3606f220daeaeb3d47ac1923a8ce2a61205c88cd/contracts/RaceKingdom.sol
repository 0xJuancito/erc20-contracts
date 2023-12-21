// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RaceKingdom is ERC20, Ownable {

  uint256 public constant MAX_SUPPLY = 3_700_000_000_000_000_000_000_000_000;
  
  constructor( 
        address _Seed,
        address _Private,
        address _Public,
        address _Team_Operations,
        address _Advisors,
        address _Play_to_Earn,
        address _Staking,
        address _Treasury
        ) ERC20("Race_Kingdom","ATOZ"){
        _mint(_Seed, 296_000_000 * (10 ** decimals()));
        _mint(_Private, 444_000_000 * (10 ** decimals()));
        _mint(_Public, 148_000_000 * (10 ** decimals()));
        _mint(_Team_Operations, 555_000_000 * (10 ** decimals()));
        _mint(_Advisors, 185_000_000 * (10 ** decimals()));
        _mint(_Play_to_Earn, 1_110_000_000 * (10 ** decimals()));
        _mint(_Staking, 555_000_000 * (10 ** decimals()));
        _mint(_Treasury, 407_000_000 * (10 ** decimals()));
  }

}