//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";

contract PIXT is ERC20Burnable, EIP712("PlanetIX", "1") {
    bytes32 private constant PERMIT_FOR_BID_HASH =
        keccak256(
            "PermitForBid(address owner,address spender,uint256 amount,address nftToken,uint256 tokenId,uint256 nonce)"
        );

    mapping(address => uint256) public nonces;

    constructor() ERC20("PlanetIX", "IXT") {
        // initial supply : 153,258,228
        _mint(msg.sender, 153258228 * 1e18);
    }

    function permitForBid(
        address owner,
        address spender,
        uint256 amount,
        address nftToken,
        uint256 tokenId,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        uint256 nonce = nonces[owner]++;
        bytes32 structHash = keccak256(
            abi.encode(PERMIT_FOR_BID_HASH, owner, spender, amount, nftToken, tokenId, nonce)
        );
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, v, r, s);
        require(signer == owner, "PIXT: INVALID_SIGNATURE");

        _approve(owner, spender, amount);
    }
}
