//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

contract AquaFarmAesV1 is ERC20PresetFixedSupply {
    
    string private _author;

    constructor() ERC20PresetFixedSupply("Aree Shards", "AES", 1000000000_000000000000000000, address(0x832F89fB7452cD32aa6B210D164b38aE906895fA)) {
        _author = "inca@besoft.co.kr";
    }

    function author() public view virtual returns (string memory) {
        return _author;
    }
}
