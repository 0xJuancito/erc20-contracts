// SPDX-License-Identifier: MIT
// File: /contracts/EYEToken.sol
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title EYENToken - ERC20 implementation
/// @notice Simple implementation of a {ERC20} token to be used as
// Eyen platform Token (EYE)
contract EYEToken is ERC20 {

    /**
    * @dev  Allocation to each channel
    */
    constructor(address airdrop,
                address marketMaker,
                address communityGrowth,
                address workReward,
                address companyReserve,
                address team,
                address liquidityMining) ERC20('EYEN Token', 'EYE'){
        _mint(airdrop, 10000000 * 10 ** decimals());
        _mint(msg.sender, 25000000 * 10 ** decimals());
        _mint(marketMaker, 45000000 * 10 ** decimals());
        _mint(communityGrowth, 25000000 * 10 ** decimals());
        _mint(workReward, 225000000 * 10 ** decimals());
        _mint(companyReserve, 40000000 * 10 ** decimals());
        _mint(team, 30000000 * 10 ** decimals());
        _mint(liquidityMining, 100000000 * 10 ** decimals());
    }
}
