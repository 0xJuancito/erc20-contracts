//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.4;

import "../../common/erc20/ERC20BaseToken.sol";

contract KZSerum is ERC20BaseToken {

    function initialize() external initializer {
        __ERC20BaseToken_init("Karmaverse Zombie Serum", "Serum");
    }

    function decimals() public view virtual override returns (uint8) {
        return 0;
    }
}