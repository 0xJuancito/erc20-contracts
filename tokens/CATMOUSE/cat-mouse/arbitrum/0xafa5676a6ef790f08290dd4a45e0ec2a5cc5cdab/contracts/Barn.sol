// SPDX-License-Identifier: MIT LICENSE
/**
        |\---/|
        | ,_, |
         \_`_/-..----.
       ___/ `   ' ,""+ \
      (__...'   __\    \
         (_,...'(_,.`__)/
 */
pragma solidity 0.8.15;

import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/vendor/arbitrum/IArbSys.sol';
import './CatMouse.sol';
import './Rice.sol';

contract Barn is Ownable, IERC721Receiver, ERC721Holder, ReentrancyGuard {
  struct UserInfo {
    uint256 alphaTotal;
    uint256 rewardDebt;
    uint256 unclaimedRewards;
  }
  struct UserInvitedInfo {
    uint256 totalInvited;
    uint256 totalRewards;
    uint256 claimedRewards;
  }

  // [user address] => [index] => [tokenId]
  mapping(address => mapping(uint16 => uint16)) private _ownedTokens;

  // [tokenId] => [index of _ownedTokens]
  mapping(uint16 => uint16) private _ownedTokensIndex;

  // [user address] => [balance]
  mapping(address => uint16) private _balances;

  // [tokenId] => [user address]
  mapping(uint16 => address) public ownerOf;

  mapping(address => UserInfo) public mouseStaked;
  mapping(address => UserInfo) public catStaked;

  // [user address] => [referral address]
  mapping(address => address) public invitedBy;
  // [user address] => [invited info]
  mapping(address => UserInvitedInfo) public invitedInfo;
  uint256 public referralRewardBalance = 10_000_000 ether;

  uint256 public mouseLastRewardBlock;
  uint256 public mouseAccAlphaPerShare;
  uint256 public mouseTotalAlphaStaked;

  uint256 public catAccAlphaPerShare;
  uint256 public catTotalAlphaStaked;

  // Cats take a 20% on all $RICE claimed
  uint8 public constant rice_claim_tax_percentage = 20;

  // amount of $RICE earned by all users
  uint256 public totalRiceSupply = 150_000_000 ether;

  uint256[6] public rewardBlockHeights;
  uint256[6] public rewardAmountsPerBlock;

  // emergency rescue to allow unstaking without any checks but without $RICE
  bool public rescueEnabled = false;

  CatMouse public immutable catMouse;
  Rice public immutable rice;

  event Claimed(address owner, uint256 cat, uint256 mouse, uint256 ReferReward);

  constructor(address _catMouse, address _rice) {
    catMouse = CatMouse(_catMouse);
    rice = Rice(_rice);
  }

  modifier updatePool_Mouse() {
    uint256 bkn = blockNumber();
    if (totalRiceSupply > 0 && bkn > mouseLastRewardBlock) {
      if (mouseTotalAlphaStaked > 0) {
        uint256 tokenReward = calculateRewards(bkn, mouseLastRewardBlock);
        if (tokenReward > 0) {
          if (tokenReward > totalRiceSupply) tokenReward = totalRiceSupply;
          unchecked {
            totalRiceSupply -= tokenReward;
          }
          mouseAccAlphaPerShare += _updatePool_Cat(tokenReward * 1e12) / mouseTotalAlphaStaked;
        }
      }
      mouseLastRewardBlock = bkn;
    }

    _;
  }

  function blockNumber() internal view returns (uint256) {
    // return block.number;
    return IArbSys(0x0000000000000000000000000000000000000064).arbBlockNumber();
  }

  function _updatePool_Cat(uint256 mouseReward) internal returns (uint256) {
    if (catTotalAlphaStaked == 0) return mouseReward;
    uint256 catReward = (mouseReward * rice_claim_tax_percentage) / 100;
    catAccAlphaPerShare += catReward / catTotalAlphaStaked;
    return mouseReward - catReward;
  }

  function uncalcMouseAlphaPerShare() public view returns (uint256) {
    uint256 bkn = blockNumber();
    if (bkn <= mouseLastRewardBlock) return 0;
    if (mouseTotalAlphaStaked == 0) return 0;
    uint256 tokenReward = calculateRewards(bkn, mouseLastRewardBlock);
    if (tokenReward > totalRiceSupply) tokenReward = totalRiceSupply;
    if (catTotalAlphaStaked == 0) return (tokenReward * 1e12) / mouseTotalAlphaStaked;
    return ((tokenReward * 1e12) * (100 - rice_claim_tax_percentage)) / 100 / mouseTotalAlphaStaked;
  }

  function uncalcCatAlphaPerShare() public view returns (uint256) {
    uint256 bkn = blockNumber();
    if (bkn <= mouseLastRewardBlock) return 0;
    if (mouseTotalAlphaStaked == 0) return 0;
    if (catTotalAlphaStaked == 0) return 0;
    uint256 tokenReward = calculateRewards(bkn, mouseLastRewardBlock);
    if (tokenReward > totalRiceSupply) tokenReward = totalRiceSupply;
    return ((tokenReward * 1e12) * rice_claim_tax_percentage) / 100 / catTotalAlphaStaked;
  }

  function pendingMouse(address _user) external view returns (uint256) {
    UserInfo storage user = mouseStaked[_user];
    uint256 accTokenPerShare = mouseAccAlphaPerShare + uncalcMouseAlphaPerShare();
    return user.unclaimedRewards + (user.alphaTotal * accTokenPerShare) / 1e12 - user.rewardDebt;
  }

  function pendingCat(address _user) external view returns (uint256) {
    UserInfo storage user = catStaked[_user];
    uint256 accTokenPerShare = catAccAlphaPerShare + uncalcCatAlphaPerShare();
    return user.unclaimedRewards + (user.alphaTotal * accTokenPerShare) / 1e12 - user.rewardDebt;
  }

  function setInviter(address user, address inviter) external {
    require(_msgSender() == address(catMouse), 'ONLY CATMOUSE');
    _setInviter(user, inviter);
  }

  function _setInviter(address user, address inviter) internal {
    if (invitedBy[user] != address(0)) return;
    if (inviter == user) return;
    invitedBy[user] = inviter;
    invitedInfo[inviter].totalInvited++;
  }

  /**
   * adds Mouse and Cats to the Barn
   * @param account the address of the staker
   * @param tokenIds the IDs of the Mouse and Cats to stake
   * @param inviter the address of the inviter
   */
  function stake(address account, uint256[] calldata tokenIds, address inviter) external updatePool_Mouse nonReentrant {
    address msgSender = _msgSender();
    require(!rescueEnabled, 'RESCUE MODE');
    require(account == msgSender || msgSender == address(catMouse), 'DONT GIVE YOUR TOKENS AWAY');

    _setInviter(account, inviter);

    // mouse
    UserInfo storage userMouse = mouseStaked[account];
    userMouse.unclaimedRewards += (userMouse.alphaTotal * mouseAccAlphaPerShare) / 1e12 - userMouse.rewardDebt;

    // cat
    UserInfo storage userCat = catStaked[account];
    userCat.unclaimedRewards += (userCat.alphaTotal * catAccAlphaPerShare) / 1e12 - userCat.rewardDebt;

    uint8[8][] memory tokenListTraits = catMouse.getTokenListTraits(tokenIds);
    uint256 catAlphaAdd = 0;
    uint256 mouseAlphaAdd = 0;

    for (uint16 i = 0; i < tokenIds.length; i++) {
      if (tokenListTraits[i][0] == 0) {
        catAlphaAdd += tokenListTraits[i][7];
      } else {
        mouseAlphaAdd += tokenListTraits[i][7];
      }
      _addTokenToOwnerEnumeration(account, uint16(tokenIds[i]));
    }
    userCat.alphaTotal += catAlphaAdd;
    catTotalAlphaStaked += catAlphaAdd;
    userMouse.alphaTotal += mouseAlphaAdd;
    mouseTotalAlphaStaked += mouseAlphaAdd;

    userMouse.rewardDebt = (userMouse.alphaTotal * mouseAccAlphaPerShare) / 1e12;
    userCat.rewardDebt = (userCat.alphaTotal * catAccAlphaPerShare) / 1e12;

    if (msgSender != address(catMouse)) {
      catMouse.batchTransferFrom(msgSender, address(this), tokenIds);
    }
  }

  /** CLAIMING / UNSTAKING */

  /**
   * realize $RICE earnings and optionally unstake tokens from the Barn / Pack
   * to unstake a Mouse it will require it has 2 days worth of $RICE unclaimed
   * @param unstake whether or not to unstake ALL of the tokens listed in tokenIds
   */
  function claim(bool unstake) external updatePool_Mouse nonReentrant {
    address account = _msgSender();
    uint256 reward_mouse = _claimMouse(account);
    uint256 reward_cat = _claimCat(account);
    uint256 reward_ref = _claimReferral(account);
    uint256 reward = reward_mouse + reward_cat + reward_ref;

    _referralReward(account, reward);

    if (unstake) {
      uint16 balance = balanceOf(account);
      require(balance > 0, 'Barn: balance is 0');

      mouseTotalAlphaStaked -= mouseStaked[account].alphaTotal;
      catTotalAlphaStaked -= catStaked[account].alphaTotal;

      delete mouseStaked[account];
      delete catStaked[account];

      uint256[] memory tokenIds = new uint256[](balance);

      for (uint16 i = 0; i < balance; i++) {
        tokenIds[i] = _ownedTokens[account][0];
        _removeTokenFromOwnerEnumeration(account, _ownedTokens[account][0]);
      }

      catMouse.batchTransferFrom(address(this), account, tokenIds);
      if (reward == 0) return;
    } else {
      require(reward > 0);
    }

    rice.transfer(account, reward);

    emit Claimed(account, reward_cat, reward_mouse, reward_ref);
  }

  function _referralReward(address account, uint256 reward) internal {
    address inviter = invitedBy[account];
    if (inviter == address(0)) return;
    if (mouseStaked[inviter].alphaTotal == 0 && catStaked[inviter].alphaTotal == 0) return;
    reward = reward / 10;
    if (reward > referralRewardBalance) reward = referralRewardBalance;
    if (reward == 0) return;

    unchecked {
      referralRewardBalance -= reward;
    }

    invitedInfo[inviter].totalRewards += reward;
  }

  function _claimMouse(address account) internal returns (uint256 reward) {
    UserInfo storage user = mouseStaked[account];

    uint256 debt = (user.alphaTotal * mouseAccAlphaPerShare) / 1e12;
    reward = user.unclaimedRewards + debt - user.rewardDebt;
    user.rewardDebt = debt;
    user.unclaimedRewards = 0;
  }

  function _claimCat(address account) internal returns (uint256 reward) {
    UserInfo storage user = catStaked[account];
    uint256 debt = (user.alphaTotal * catAccAlphaPerShare) / 1e12;
    reward = user.unclaimedRewards + debt - user.rewardDebt;
    user.rewardDebt = debt;
    user.unclaimedRewards = 0;
  }

  function _claimReferral(address account) internal returns (uint256 reward) {
    UserInvitedInfo storage user = invitedInfo[account];
    reward = user.totalRewards - user.claimedRewards;
    user.claimedRewards = user.totalRewards;
  }

  /**
   * calculate the amount of $RICE earned
   */
  function calculateRewards(uint256 currentBlock, uint256 lastBlock) public view returns (uint256 earned) {
    for (uint256 i = 0; i < rewardBlockHeights.length; i++) {
      uint256 height = rewardBlockHeights[i];

      if (lastBlock >= height) continue;
      uint256 rewardPerBlock = rewardAmountsPerBlock[i];

      if (currentBlock <= height) {
        earned += (currentBlock - lastBlock) * rewardPerBlock;
        return earned;
      }
      earned += (height - lastBlock) * rewardPerBlock;
      lastBlock = height;
    }
    earned += (currentBlock - lastBlock) * rewardAmountsPerBlock[5];
  }

  /**
   * emergency unstake tokens
   */
  function rescue(uint16 count) external {
    require(rescueEnabled, 'RESCUE DISABLED');
    address account = _msgSender();
    uint256[] memory tokenIds = new uint256[](count);

    for (uint16 i = 0; i < count; i++) {
      tokenIds[i] = _ownedTokens[account][0];
      _removeTokenFromOwnerEnumeration(account, _ownedTokens[account][0]);
    }
    catMouse.batchTransferFrom(address(this), account, tokenIds);
  }

  function leaveByIds(uint256[] calldata tokenIds) external updatePool_Mouse nonReentrant {
    address account = _msgSender();

    // mouse
    UserInfo storage userMouse = mouseStaked[account];
    userMouse.unclaimedRewards += (userMouse.alphaTotal * mouseAccAlphaPerShare) / 1e12 - userMouse.rewardDebt;

    // cat
    UserInfo storage userCat = catStaked[account];
    userCat.unclaimedRewards += (userCat.alphaTotal * catAccAlphaPerShare) / 1e12 - userCat.rewardDebt;

    uint8[8][] memory tokenListTraits = catMouse.getTokenListTraits(tokenIds);
    uint256 catAlphaSub = 0;
    uint256 mouseAlphaSub = 0;

    for (uint16 i = 0; i < tokenIds.length; i++) {
      if (tokenListTraits[i][0] == 0) {
        catAlphaSub += tokenListTraits[i][7];
      } else {
        mouseAlphaSub += tokenListTraits[i][7];
      }
      _removeTokenFromOwnerEnumeration(account, uint16(tokenIds[i]));
    }
    userCat.alphaTotal -= catAlphaSub;
    catTotalAlphaStaked -= catAlphaSub;
    userMouse.alphaTotal -= mouseAlphaSub;
    mouseTotalAlphaStaked -= mouseAlphaSub;

    userMouse.rewardDebt = (userMouse.alphaTotal * mouseAccAlphaPerShare) / 1e12;
    userCat.rewardDebt = (userCat.alphaTotal * catAccAlphaPerShare) / 1e12;

    catMouse.batchTransferFrom(address(this), account, tokenIds);
  }

  /**
   * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
   */
  function tokenOfOwnerByIndex(address user, uint256 index) public view virtual returns (uint256) {
    return uint256(_ownedTokens[user][uint16(index)]);
  }

  /**
   * @dev See {IERC721-balanceOf}.
   */
  function balanceOf(address user) public view virtual returns (uint16) {
    require(user != address(0), 'ERC721: balance query for the zero address');
    return _balances[user];
  }

  /**
   * @dev Private function to add a token to this extension's ownership-tracking data structures.
   * @param to address representing the new owner of the given token ID
   * @param tokenId uint16 ID of the token to be added to the tokens list of the given address
   */
  function _addTokenToOwnerEnumeration(address to, uint16 tokenId) private {
    uint16 length = _balances[to];
    _ownedTokens[to][length] = tokenId;
    _ownedTokensIndex[tokenId] = length;

    _balances[to] = length + 1;
    ownerOf[tokenId] = to;
  }

  /**
   * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
   * while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
   * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
   * This has O(1) time complexity, but alters the order of the _ownedTokens array.
   * @param from address representing the previous owner of the given token ID
   * @param tokenId uint16 ID of the token to be removed from the tokens list of the given address
   */
  function _removeTokenFromOwnerEnumeration(address from, uint16 tokenId) private {
    require(ownerOf[tokenId] == from, 'Barn: not owner');
    // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
    // then delete the last slot (swap and pop).

    uint16 lastTokenIndex = _balances[from] - 1;
    uint16 tokenIndex = _ownedTokensIndex[tokenId];

    // When the token to delete is the last token, the swap operation is unnecessary
    if (tokenIndex != lastTokenIndex) {
      uint16 lastTokenId = _ownedTokens[from][lastTokenIndex];

      _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
      _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
    }

    // This also deletes the contents at the last position of the array
    delete _ownedTokensIndex[tokenId];
    delete _ownedTokens[from][lastTokenIndex];
    delete ownerOf[tokenId];
    _balances[from]--;
  }

  /** ADMIN */

  /**
   * allows owner to enable "rescue mode"
   * simplifies accounting, prioritizes tokens out in emergency
   */
  function setRescueEnabled(bool _enabled) external onlyOwner {
    rescueEnabled = _enabled;
  }

  function initialize(uint256 beginBlock, uint256 blocksPerSec) external onlyOwner {
    require(rewardBlockHeights[0] == 0, 'ALREADY INITIALIZED');
    require(rice.balanceOf(address(this)) >= (totalRiceSupply + referralRewardBalance), 'NOT ENOUGH RICE');

    // 0   ~ 30  days, 50_000_000 + 5_555_555
    // 30  ~ 60  days, 25_000_000 + 2_777_777
    // 60  ~ 120 days, 25_000_000 + 1666668
    // 120 ~ 240 days, 25_000_000
    // 240 ~ 480 days, 25_000_000

    uint256 stageSupply = 25_000_000 ether;
    uint256 stageBlocks = 30 days * blocksPerSec;
    uint256 rewardPerBlock = stageSupply / stageBlocks;

    rewardBlockHeights = [
      beginBlock, // 0
      beginBlock + stageBlocks, // 0 ~ 30 days
      beginBlock + (stageBlocks * 2), // 30 ~ 60 days
      beginBlock + (stageBlocks * 4), // 60 ~ 120 days
      beginBlock + (stageBlocks * 8), // 120 ~ 240 days
      beginBlock + (stageBlocks * 16) // 240 ~ 480 days
    ];
    rewardAmountsPerBlock = [
      0,
      rewardPerBlock * 2, // 0 ~ 30 days
      rewardPerBlock, // 30 ~ 60 days
      rewardPerBlock / 2, // 60 ~ 120 days
      rewardPerBlock / 4, // 120 ~ 240 days
      rewardPerBlock / 8 // 240 ~ 480 days
    ];
  }
}
