# Multichain ERC20

> Check ERC20 token implementations on multiple chains.

🕵️ This is part of an on-going effort of auditing protocols on different chains. You can check [multichain-auditor](https://github.com/0xJuancito/multichain-auditor) to learn more.

For any feedback, ideas, or if you think some contract should be removed, please open an issue, or contact me at [0xJuancito](https://twitter.com/0xJuancito).

## Structure

- Contracts are grouped by their symbol + id
- Proxy contracts contain their implementation on a sub-directory.

##### Example:

USDT in Polygon has a proxy. Its addresses are:

- **Proxy:** [tokens/USDT/tether/polygon/${proxy}/UChildERC20Proxy.sol](tokens/USDT/tether/polygon/0xc2132d05d31c914a87c6611c10748aeb04b58e8f/UChildERC20Proxy.sol)
- **Implementation:** [tokens/USDT/tether/polygon/${proxy}/${implementation}/UChildERC20.sol](tokens/USDT/tether/polygon/0xc2132d05d31c914a87c6611c10748aeb04b58e8f/0x7ffb3d637014488b63fb9858e279385685afc1e2/UChildERC20.sol)

* There are multiple tokens with the same symbols, so they are grouped with an additional id, as in `USDT/tether`.

## Future Plans

Analyze contracts and curate data to check differences on different chains:

- [ ] Decimals
- [ ] Check for [weird implementations](https://github.com/d-xo/weird-erc20) (missing return, fee on transfer, etc
- [ ] Implementation details (upgradeable, pausable, etc)

##### Example:

| Token | Chain | Decimals | Upgradeable | Pausable | [Missing Return](https://github.com/d-xo/weird-erc20?tab=readme-ov-file#missing-return-values) |
| :---: | :---: | :---: | :---: | :---: | :---: |
| USDT  | [Ethereum](https://etherscan.io/token/0xdac17f958d2ee523a2206206994597c13d831ec7#code) | 6 | ❌ | ✅ | ✅ |
| USDT  | [Polygon](https://polygonscan.com/token/0xc2132d05d31c914a87c6611c10748aeb04b58e8f#code) | 6 | ✅ | ❌ | ❌ |
| USDT  | [BSC](https://bscscan.com/token/0x55d398326f99059ff775485246999027b3197955#readContract) | 18 | ❌ | ❌ | ❌ |

## Acknowledgements

- Inspired by the great [smart-contract-sanctuary](https://github.com/tintinweb/smart-contract-sanctuary) repository 🌴🦕.
- Coins list provided by the [CoinGecko API](https://www.coingecko.com/api/documentation).
