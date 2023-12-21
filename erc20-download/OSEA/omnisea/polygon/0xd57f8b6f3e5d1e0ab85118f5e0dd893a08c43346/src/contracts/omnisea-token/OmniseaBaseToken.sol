pragma solidity ^0.8.7;

import "../oft/extension/BasedOFT.sol";

contract OmniseaBaseToken is BasedOFT {
    constructor(address _layerZeroEndpoint) BasedOFT("Omnisea", "OSEA", _layerZeroEndpoint) {
        _mint(_msgSender(), (1000 * 10**6 * 10**18));
    }
}