// SPDX-License-Identifier: MIT LICENSE
pragma solidity 0.8.15;

contract CatMouseAlpha {
  // list of aliases,rarities for Walker's Alias algorithm
  // 0 - 6 are associated with Mouse, 7 - 13 are associated with Cats
  uint8[][14] public aliases;
  uint8[][14] public rarities;

  // mapping from tokenId to a struct containing the token's traits
  mapping(uint256 => uint8[8]) public tokenTraits;

  uint16[] public alphaOfCat;
  uint16[] public alphaOfMouse;

  constructor() {
    // Cat body
    rarities[0] = [255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255];
    aliases[0] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

    // Cat face
    rarities[1] = [255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255];
    aliases[1] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];

    // Cat glasses
    rarities[2] = [255, 170, 170, 170];
    aliases[2] = [0, 0, 0, 0];

    // Cat ornaments
    rarities[3] = [255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255];
    aliases[3] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18];

    // Cat headwear
    rarities[4] = [239, 239, 191, 255, 239, 239, 239, 239, 239, 239, 239, 239];
    aliases[4] = [3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3];

    // Cat tool
    rarities[5] = [255, 255, 255, 255, 255, 255, 255, 255];
    aliases[5] = [0, 1, 2, 3, 4, 5, 6, 7];

    // Cat rarity
    rarities[6] = [0, 0, 0, 0, 0, 255, 127, 229, 114];
    aliases[6] = [5, 5, 5, 6, 6, 5, 5, 6, 6];

    // Mouse body
    rarities[7] = [255, 255, 255, 255, 255, 255];
    aliases[7] = [0, 1, 2, 3, 4, 5];

    // Mouse face
    rarities[8] = [255, 255, 255, 255];
    aliases[8] = [0, 1, 2, 3];

    // Mouse glasses
    rarities[9] = [255, 159, 159, 159, 159];
    aliases[9] = [0, 0, 0, 0, 0];

    // Mouse ornaments
    rarities[10] = [255, 255, 255, 255, 255, 255, 255];
    aliases[10] = [0, 1, 2, 3, 4, 5, 6];

    // Mouse headwear
    rarities[11] = [255, 255, 255, 255, 255];
    aliases[11] = [0, 1, 2, 3, 4];

    // Mouse tool
    rarities[12] = [255, 255, 255, 255, 255];
    aliases[12] = [0, 1, 2, 3, 4];

    // Mouse rarity
    rarities[13] = [0, 255];
    aliases[13] = [1, 1];
  }

  function alphaAdd(uint16 tokenId) internal {
    uint8 alpha = tokenTraits[tokenId][7];
    if (isMouse(tokenId)) {
      for (uint8 i = 0; i < alpha; i++) {
        alphaOfMouse.push(tokenId);
      }
    } else {
      for (uint8 i = 0; i < alpha; i++) {
        alphaOfCat.push(tokenId);
      }
    }
  }

  /**
   * selects the species and all of its traits based on the seed value
   * @param seed a pseudorandom 256 bit number to derive traits from
   * @return traits - a struct of randomly selected traits
   */
  function _selectTraits(uint256 tokenId, uint256 seed) internal returns (uint8[8] memory traits) {
    traits[0] = (seed & 0xFFFF) % 10 == 0 ? 0 : 1; // 0 cat, 1 mouse
    uint8 shift = traits[0] == 1 ? 7 : 0;
    for (uint8 i = 0; i < 7; i++) {
      seed >>= 16;
      traits[1 + i] = _selectTrait(uint16(seed & 0xFFFF), i + shift);
    }
    tokenTraits[tokenId] = traits;
  }

  /**
   * uses A.J. Walker's Alias algorithm for O(1) rarity table lookup
   * ensuring O(1) instead of O(n) reduces mint cost by more than 50%
   * probability & alias tables are generated off-chain beforehand
   * @param seed portion of the 256 bit seed to remove trait correlation
   * @param traitType the trait type to select a trait for
   * @return the ID of the randomly selected trait
   */
  function _selectTrait(uint16 seed, uint8 traitType) internal view returns (uint8) {
    uint8 trait = uint8(seed) % uint8(rarities[traitType].length);
    if (seed >> 8 < rarities[traitType][trait]) return trait;
    return aliases[traitType][trait];
  }

  function alphaOfCatLength() public view returns (uint256) {
    return alphaOfCat.length;
  }

  function alphaOfMouseLength() public view returns (uint256) {
    return alphaOfMouse.length;
  }

  function isCat(uint256 tokenId) public view returns (bool) {
    return tokenTraits[tokenId][0] == 0;
  }

  function isMouse(uint256 tokenId) public view returns (bool) {
    return tokenTraits[tokenId][0] == 1;
  }

  function isCats(uint256[] memory tokenIds) public view returns (bool[] memory bools) {
    bools = new bool[](tokenIds.length);
    for (uint16 i = 0; i < tokenIds.length; i++) {
      bools[i] = tokenTraits[tokenIds[i]][0] == 0;
    }
  }
}
