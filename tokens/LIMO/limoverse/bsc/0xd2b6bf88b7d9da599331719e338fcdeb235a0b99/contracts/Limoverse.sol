// contracts/Limoverse.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Limoverse is ERC20 {
    address constant public publicSale = 0x19400c69ce57ab38a1b05679Dc360A2ff8fC44D8;
    address constant public stakingPool = 0xb9AD0d43BCbeFdD07D9F52A3AcD9Cee56eDb7404;
    address constant public marketingAndOperations = 0xEb0aB21BdC8a150Af08bED5D085E4C0D77DeDeB4;
    address constant public teamAdvisors = 0x364F1C044F61F28120B20F5261f694B8a58E61A6;
    address constant public airdrop = 0x33dC2466C2EcfFDde98D117B39E6bf3F93250ad1;
    address constant public limoverseForProfit = 0x70118b36Ec0403e06fC9d25c0756C5853377BBbA;
    address constant public foundersWallet = 0x65804B87c4F60d98db4386e43b9C965659C94bbf;

    constructor() ERC20("LIMOVERSE", "LIMO") {
        _mint(publicSale, 1000000000 * 10 ** decimals());
        _mint(stakingPool, 1200000000 * 10 ** decimals());
        _mint(marketingAndOperations, 900000000 * 10 ** decimals());
        _mint(teamAdvisors, 500000000 * 10 ** decimals());
        _mint(airdrop, 300000000 * 10 ** decimals());
        _mint(limoverseForProfit, 3600000000 * 10 ** decimals());
        _mint(foundersWallet, 2500000000 * 10 ** decimals());
    }
}
