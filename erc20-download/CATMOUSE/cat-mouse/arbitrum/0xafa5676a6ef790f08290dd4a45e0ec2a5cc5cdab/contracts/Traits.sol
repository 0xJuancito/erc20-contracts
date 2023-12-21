// SPDX-License-Identifier: MIT LICENSE
/**
        A_A
       (-.-)
        |-|
       /   \
 */
pragma solidity 0.8.15;
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/utils/Base64.sol';
import './CatMouse.sol';

contract Traits is Ownable {
  using Strings for uint16;
  struct Trait {
    string name;
    string data;
  }

  // traitType => traitId => Trait
  mapping(uint32 => mapping(uint32 => Trait)) public traitData;

  mapping(uint8 => string) public traitName;

  string public pre =
    '<svg width="100%" height="100%" version="1.1" viewBox="0 0 40 40" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"><style>image{x:4;y:4;width:32;height:32;image-rendering:pixelated;transition:all ease .4s;}svg:hover image[data-glasses]{y:6;}svg:hover image[data-headwear]{y:0;transition:all ease .2s;}</style>';
  string public end = '</svg>';
  CatMouse public catMouse;

  function getAttr(uint16 tokenId_) public view returns (Trait[8] memory, uint8) {
    uint8[8] memory s = catMouse.getTokenTraits(tokenId_);
    Trait[8] memory args;
    uint8 begin_ = 0;
    if (s[0] == 1) begin_ = 8; // mouse
    for (uint8 i = 1; i < s.length; i++) {
      args[i] = traitData[i + begin_][s[i]];
    }
    return (args, begin_);
  }

  function drawSVG(uint16 tokenId_) public view returns (string memory) {
    (Trait[8] memory args, ) = getAttr(tokenId_);

    return
      string(
        abi.encodePacked(
          pre,
          args[0].data,
          args[1].data,
          args[2].data,
          args[3].data,
          //
          abi.encodePacked(
            //
            args[4].data,
            args[5].data,
            args[6].data,
            args[7].data,
            end
          )
        )
      );
  }

  /**
   * generates an attribute for the attributes array in the ERC721 metadata standard
   */
  function attributeForTypeAndValue(string memory typeName_, Trait memory trait_) internal pure returns (string memory) {
    if (bytes(trait_.data).length == 0) return '';
    return string(abi.encodePacked('{"trait_type":"', typeName_, '","value":"', trait_.name, '"},'));
  }

  /**
   * generates an array composed of all the individual traits and values
   */
  function compileAttributes(uint16 tokenId_) public view returns (string memory) {
    (Trait[8] memory args, uint8 begin_) = getAttr(tokenId_);
    string memory traits = string(
      abi.encodePacked(
        attributeForTypeAndValue(traitName[0 + begin_], args[0]),
        attributeForTypeAndValue(traitName[1 + begin_], args[1]),
        attributeForTypeAndValue(traitName[2 + begin_], args[2]),
        attributeForTypeAndValue(traitName[3 + begin_], args[3]),
        abi.encodePacked(
          //
          attributeForTypeAndValue(traitName[4 + begin_], args[4]),
          attributeForTypeAndValue(traitName[5 + begin_], args[5]),
          attributeForTypeAndValue(traitName[6 + begin_], args[6]),
          attributeForTypeAndValue(traitName[7 + begin_], args[7])
        )
      )
    );

    return
      string(
        abi.encodePacked(
          '[{"trait_type":"type","value":"',
          begin_ == 0 ? 'Cat' : 'Mouse',
          '"},',
          traits,
          '{"trait_type":"generation","value":"Gen ',
          tokenId_ <= catMouse.PAY_ETH_1() ? '0' : '1',
          '"}]'
        )
      );
  }

  /**
   * generates a base64 encoded metadata response without referencing off-chain content
   */
  function tokenURI(uint16 tokenId_) public view returns (string memory) {
    (, uint16 begin_) = getAttr(tokenId_);
    string memory metadata = string(
      abi.encodePacked(
        '{"name": "',
        begin_ == 0 ? 'Cat #' : 'Mouse #',
        tokenId_.toString(),
        '", "description": "https://catmouse.world Cat and Mouse is a pixel game built on Arbitrum, with a total supply of 50,000, 10% cats and 90% mice in a completely randomised style. 100% Creative and completely on-chain game.","image": "data:image/svg+xml;base64,',
        Base64.encode(bytes(drawSVG(tokenId_))),
        '", "attributes":',
        compileAttributes(tokenId_),
        '}'
      )
    );
    return string(abi.encodePacked('data:application/json;base64,', Base64.encode(bytes(metadata))));
  }

  function setPre(string calldata pre_) external onlyOwner {
    pre = pre_;
  }

  function setEnd(string calldata end_) external onlyOwner {
    end = end_;
  }

  function updateTraitName(uint8[] calldata indexs, string[] calldata names) external onlyOwner {
    for (uint8 i = 0; i < indexs.length; i++) {
      traitName[indexs[i]] = names[i];
    }
  }

  function uploadTraits(uint32 traitType, uint32[] calldata traitIds, Trait[] calldata traits) external onlyOwner {
    for (uint256 i = 0; i < traits.length; i++) {
      traitData[traitType][traitIds[i]] = traits[i];
    }
  }

  function setCatMouse(address _catMouse) external onlyOwner {
    catMouse = CatMouse(_catMouse);
  }
}
