// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

import './openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol';

contract WhnsTokenV1 is ERC20Upgradeable {
  struct MintArgs {
    address to;
    uint256 amount;
  }

  /**
   * @dev The address with permission to mint new tokens
   */
  address public minter;

  /**
   * @dev Tracking for used redeem tokens.
   */
  mapping(bytes32 => bool) public isRedeemTokenUsed;

  /**
   * @dev Mapping of interface ids to whether or not it's supported.
   */
  mapping(bytes4 => bool) internal _supportedInterfaces;

  event TokensRedeemed(
    bytes32 indexed redeemToken,
    address indexed from,
    uint256 amount
  );

  function initialize(address _minter) public initializer {
    __ERC20_init('Wrapped HNS', 'WHNS');
    minter = _minter;

    _supportedInterfaces[this.supportsInterface.selector] = true; // ERC165 itself
    _supportedInterfaces[0x36372b07] = true; // ERC20
    _supportedInterfaces[
      this.name.selector ^ this.symbol.selector ^ this.decimals.selector
    ] = true; // ERC20 metadata
    _supportedInterfaces[this.name.selector] = true;
    _supportedInterfaces[this.symbol.selector] = true;
    _supportedInterfaces[this.decimals.selector] = true;
  }

  function decimals() public pure override returns (uint8) {
    return 6;
  }

  /**
   * @dev Mint tokens to an address. Can only be called by the recognized minter.
   *
   * @param _to The address to mint to
   * @param _amount The amount (in dollarydoos) to mint
   */
  function mint(address _to, uint256 _amount) external {
    require(msg.sender == minter);
    _mint(_to, _amount);
  }

  /**
   * @dev Mint tokens to a set of addresses. Can only be called by the recognized
   * minter.
   *
   * @param _mints The set of {to: address, amount: uint256} pairs
   */
  function batchMint(MintArgs[] calldata _mints) external {
    require(msg.sender == minter);
    for (uint256 i = 0; i < _mints.length; i++) {
      _mint(_mints[i].to, _mints[i].amount);
    }
  }

  /**
   * @dev Allows a token holder to redeem tokens to real HNS in a Namebase account.
   * A particular redeem token can only be used once.
   *
   * @param _amount the number of dollarydoos to redeem
   * @param _redeemToken 32 bytes to identify the redemption, provided by Namebase
   */
  function redeem(uint256 _amount, bytes32 _redeemToken) external {
    require(isRedeemTokenUsed[_redeemToken] == false);
    isRedeemTokenUsed[_redeemToken] = true;
    _burn(msg.sender, _amount);
    emit TokensRedeemed(_redeemToken, msg.sender, _amount);
  }

  /**
   * @dev Returns true if this contract implements the interface defined by
   * `interfaceId`. See the corresponding
   * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
   * to learn more about how these ids are created.
   *
   * This function call must use less than 30 000 gas.
   */
  function supportsInterface(bytes4 _interfaceId) external view returns (bool) {
    return _supportedInterfaces[_interfaceId];
  }
}
