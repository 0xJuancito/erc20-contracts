// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/presets/ERC20PresetMinterPauserUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

import "./interfaces/ITokenReceiver.sol";

contract KWS is ERC20PresetMinterPauserUpgradeable {
  using AddressUpgradeable for address;
  using SafeMathUpgradeable for uint256;

  bytes32 public constant TOKEN_RECEIVER_ROLE = keccak256("TOKEN_RECEIVER_ROLE");

  function init() public virtual initializer {
    _totalMinted = 0;

    __ERC20PresetMinterPauser_init("Knight War Spirits", "KWS");
    _setupRole(TOKEN_RECEIVER_ROLE, _msgSender());
  }

  uint256 internal _totalMinted;
  uint256 constant TOTAL_SUPPLY = 5 * 10 ** 8 * (10 ** 18);

  function totalMinted() public view returns(uint256) {
    return _totalMinted;
  }

  /**
   * @dev Creates `amount` new tokens for `to`.
   *
   * See {ERC20-_mint}.
   *
   * Requirements:
   *
   * - the caller must have the `MINTER_ROLE`.
   */
  function mint(address to, uint256 amount) public virtual override(ERC20PresetMinterPauserUpgradeable) {
    require(TOTAL_SUPPLY - _totalMinted >= amount, "KWS: Reach total supply");
    ERC20PresetMinterPauserUpgradeable.mint(to, amount);
    _totalMinted = _totalMinted.add(amount);
  }

  mapping(address => bool) internal _tokenReceivers;
  function isTokenReceiver(address addr) public view returns(bool) {
    return _tokenReceivers[addr];
  }

  function setTokenReceiver(address addr, bool status) public onlyRole(TOKEN_RECEIVER_ROLE) {
    _tokenReceivers[addr] = status;
  }

  function _afterTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal virtual override {
    // self implement a part of IERC777
    if (to.isContract() && _tokenReceivers[to]) {
      ITokenReceiver(to).tokensReceived(address(this), from, to, amount);
    }
  }
}
