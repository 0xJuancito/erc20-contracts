// SPDX-License-Identifier: MIT LICENSE

/**
       /\_/\
      | o o |
       > ^ <
 */

pragma solidity 0.8.15;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';
import '@openzeppelin/contracts/vendor/arbitrum/IArbSys.sol';
import './Traits.sol';
import './Rice.sol';
import './Barn.sol';
import './CatMouseAlpha.sol';

contract CatMouse is CatMouseAlpha, ERC721Enumerable, ERC721Holder, Ownable {
  using ECDSA for bytes32;
  uint256 public constant MINT_PRICE_0 = .01 ether;
  uint256 public constant MINT_PRICE_1 = .02 ether;
  uint256 public constant MINT_PRICE_2 = .04 ether;

  uint16 public PAY_ETH_0 = 1000;
  uint16 public constant PAY_ETH_1 = 4000;
  uint16 public constant PAY_ETH_2 = 10000;
  uint16 public constant TOTAL_SUPPLY = 50000;

  uint256 public constant RICE_COST_INC = 0.1 ether;

  // number of tokens have been minted so far
  uint16 public minted;
  address public commitmentAdmin;

  struct Commitment {
    bool stake;
    bool claimed;
    address account;
    uint256 commitment;
  }

  // [tokenId] => [Commitment]
  mapping(uint16 => Commitment) public commitments;

  // [account] => [whitelistMintedCount]
  mapping(address => uint8) public whitelistMintedCount;

  mapping(address => uint16[]) public catches;

  Barn public barn;
  Rice public immutable rice;
  Traits public traits;

  event Mint(address indexed account, uint256[] tokenIds);
  event Catch(address indexed account, uint16 tokenId);

  constructor(address _rice, address _traits, address _commitmentAdmin) ERC721('Cat & Mouse', 'Cat Mouse Game') {
    rice = Rice(_rice);
    traits = Traits(_traits);
    commitmentAdmin = _commitmentAdmin;
  }

  function createCommitment() internal view returns (uint256) {
    uint256 bkn = IArbSys(0x0000000000000000000000000000000000000064).arbBlockNumber();
    return uint256(keccak256(abi.encodePacked(tx.origin, minted, IArbSys(0x0000000000000000000000000000000000000064).arbBlockHash(bkn - 1))));
    // uint256 bkn = block.number;
    // return uint256(keccak256(abi.encodePacked(tx.origin, minted, blockhash(bkn - 1))));
  }

  function mint(uint8 amount, bool stake, address inviter, bytes calldata signature) external payable {
    require(tx.origin == _msgSender(), 'Only EOA');
    require(whitelistMintedCount[tx.origin] + amount <= 6, 'Exceeds max mint amount');
    require(minted + amount <= PAY_ETH_0, 'All tokens minted');
    require(amount > 0, 'Invalid mint amount');
    require(amount * MINT_PRICE_0 == msg.value, 'Invalid payment amount');
    bytes32 message = keccak256(abi.encodePacked(tx.origin, address(this), 'mint'));
    require(message.toEthSignedMessageHash().recover(signature) == commitmentAdmin, 'Invalid signature');
    whitelistMintedCount[tx.origin] += amount;

    _preMint(tx.origin, amount, stake);
    barn.setInviter(tx.origin, inviter);
  }

  function mint(uint8 amount, bool stake, address inviter) external payable {
    require(minted >= PAY_ETH_0, 'Pre-minter enabled');
    require(tx.origin == _msgSender(), 'Only EOA');
    require(amount > 0 && amount <= 10, 'Invalid mint amount');
    if (minted < PAY_ETH_1) {
      require(minted + amount <= PAY_ETH_1, 'All tokens on-sale already sold');
      require(amount * MINT_PRICE_1 == msg.value, 'Invalid payment amount');
    } else if (minted < PAY_ETH_2) {
      require(minted + amount <= PAY_ETH_2, 'All tokens on-sale already sold');
      require(amount * MINT_PRICE_2 == msg.value, 'Invalid payment amount');
    } else {
      require(minted + amount <= TOTAL_SUPPLY, 'All tokens minted');
      require(msg.value == 0);
      rice.burnFrom(tx.origin, minted * RICE_COST_INC * amount + (RICE_COST_INC * (amount * (amount + 1))) / 2);
    }
    _preMint(tx.origin, amount, stake);
    barn.setInviter(tx.origin, inviter);
  }

  function _preMint(address to, uint8 amount, bool stake) internal {
    uint256[] memory tokenIds = new uint256[](amount);
    uint256 commitment = createCommitment();
    uint16 tokenId = minted;
    for (uint8 i = 0; i < amount; i++) {
      tokenId++;
      tokenIds[i] = tokenId;
      commitments[tokenId] = Commitment({ stake: stake, claimed: false, account: to, commitment: commitment });
    }
    minted = tokenId;
    emit Mint(to, tokenIds);
  }

  function hatch(uint16[] calldata tokenIds, bytes[] calldata signatures) external {
    for (uint256 i = 0; i < tokenIds.length; i++) {
      uint16 tokenId = tokenIds[i];
      Commitment storage cmt = commitments[tokenId];
      require(!cmt.claimed, 'token already claimed');
      require(cmt.commitment > 0, 'invalid token id');
      cmt.claimed = true;

      bytes32 message = keccak256(abi.encodePacked(tokenId, cmt.account, cmt.commitment, address(this), 'hatch'));
      require(message.toEthSignedMessageHash().recover(signatures[i]) == commitmentAdmin, 'Invalid signature');
      uint256 seed = uint256(message);

      _selectTraits(tokenId, seed);

      address recipient = _selectRecipient(cmt.account, seed, tokenId);

      alphaAdd(tokenId);

      if (recipient != cmt.account) {
        catches[recipient].push(tokenId);
        _safeMint(address(this), tokenId);
        emit Catch(recipient, tokenId);
      } else if (cmt.stake) {
        _safeMint(address(barn), tokenId);
        uint256[] memory stakeIds = new uint256[](1);
        stakeIds[0] = tokenId;
        barn.stake(cmt.account, stakeIds, address(0));
      } else {
        _safeMint(cmt.account, tokenId);
      }
    }
  }

  function mintCatches(uint16 count) external {
    require(count > 0, 'Invalid mint amount');
    uint256 len = catches[msg.sender].length;
    require(len > 0, 'No catch tokens');
    uint16 mintCount;
    while (len > 0) {
      uint16 tokenId = catches[msg.sender][len - 1];
      catches[msg.sender].pop();
      mintCount++;
      _safeTransfer(address(this), msg.sender, tokenId, '');
      if (mintCount >= count) return;
      len = catches[msg.sender].length;
    }
  }

  function batchTransferFrom(address from, address to, uint256[] memory tokenIds) external {
    for (uint16 i = 0; i < tokenIds.length; i++) {
      transferFrom(from, to, tokenIds[i]);
    }
  }

  function batchTransferFrom(address from, address[] memory toList, uint256[] memory tokenIds) external {
    for (uint16 i = 0; i < toList.length; i++) {
      transferFrom(from, toList[i], tokenIds[i]);
    }
  }

  /** INTERNAL */

  /**
   * the remaining 80% have a 10% chance to be given to a random cat
   * @param seed a random value to select a recipient from
   * @return the address of the recipient
   */
  function _selectRecipient(address user, uint256 seed, uint16 tokenId) internal view returns (address) {
    if (tokenId <= PAY_ETH_2 || ((seed >> 245) % 10) != 0) return user; // top 10 bits haven't been used
    address thief = randomCatOwner(seed >> 144); // 144 bits reserved for trait selection
    if (thief == address(0)) return user;
    return thief;
  }

  /** READ */
  function getTokenTraits(uint16 tokenId) public view returns (uint8[8] memory) {
    return tokenTraits[tokenId];
  }

  function getTokenListTraits(uint256[] memory tokenIds) public view returns (uint8[8][] memory list) {
    list = new uint8[8][](tokenIds.length);
    for (uint256 i = 0; i < tokenIds.length; i++) {
      list[i] = tokenTraits[tokenIds[i]];
    }
  }

  function getCatches(address account) public view returns (uint16[] memory) {
    return catches[account];
  }

  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    require(_exists(tokenId), 'ERC721Metadata: URI query for nonexistent token');
    return traits.tokenURI(uint16(tokenId));
  }

  function randomCatOwner(uint256 seed) public view returns (address) {
    if (alphaOfCat.length == 0) return address(0);
    return ownerAddress(alphaOfCat[seed % alphaOfCat.length]);
  }

  // barn/this
  function ownerAddress(uint16 tokenId) public view returns (address) {
    address tokenOwner = ownerOf(tokenId);
    if (tokenOwner == address(barn)) return barn.ownerOf(tokenId);
    if (tokenOwner == address(this)) return address(0);
    return tokenOwner;
  }

  /** ADMIN */
  function setBarn(address newBarn) external onlyOwner {
    require(address(barn) == address(0), 'Barn already set');
    barn = Barn(newBarn);
  }

  function closeWhitelist() external onlyOwner {
    require(minted < PAY_ETH_0, 'Whitelist already closed');
    PAY_ETH_0 = minted;
  }

  function setCommitmentAdmin(address newCommitmentAdmin) external onlyOwner {
    commitmentAdmin = newCommitmentAdmin;
  }

  function withdraw(IERC20 token, address to, uint256 amount) external onlyOwner {
    if (address(token) == address(0)) {
      payable(to).transfer(amount);
    } else {
      token.transfer(to, amount);
    }
  }

  function setTraits(address newTraits) external onlyOwner {
    traits = Traits(newTraits);
  }
}
