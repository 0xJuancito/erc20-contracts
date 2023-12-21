// SPDX-License-Identifier: MIT
// The first Dog token on Base.
// Want some $DOG? -> https://twitter.com/ImpossibleNFT/status/1679594153473187842

pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BasicDogMeme is ERC20 {
    constructor() ERC20("Basic Dog Meme", "DOG") {
        _mint(msg.sender, 1_000_000_000 ether);
    }
}