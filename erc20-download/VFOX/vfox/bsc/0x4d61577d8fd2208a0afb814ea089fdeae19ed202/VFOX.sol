pragma solidity 0.5.16;

import "./BEP20Token.sol";

contract Token2 is BEP20Token {
    constructor() public {
        _initialize("VFOX", "VFOX", 18, 21 * 10**6 * 10**18, false);
    }
}
