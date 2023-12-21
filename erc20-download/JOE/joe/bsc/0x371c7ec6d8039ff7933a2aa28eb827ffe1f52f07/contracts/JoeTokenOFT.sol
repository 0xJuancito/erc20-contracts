pragma solidity ^0.8.0;

import "@layerzerolabs/solidity-examples/contracts/token/oft/v2/fee/OFTWithFee.sol";

contract JoeTokenOFT is OFTWithFee {
    constructor(address _lzEndpoint) OFTWithFee("JoeToken", "JOE", 8, _lzEndpoint){}
}