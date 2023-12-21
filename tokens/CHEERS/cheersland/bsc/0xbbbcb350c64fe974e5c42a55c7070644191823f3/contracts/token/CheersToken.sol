// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CheersToken is ERC20("CHEERS", "CHEERS") {

    constructor(
        address _ownerAddress
    ) public {
        _mint(_ownerAddress, 100000000 * 10 ** 18);
    }

}
