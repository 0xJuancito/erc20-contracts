/**
 * https://arcadeum.io
 * https://arcadeum.gitbook.io/arcadeum
 * https://twitter.com/arcadeum_io
 * https://discord.gg/qBbJ2hNPf8
 */

// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../interfaces/external/IWETH9.sol";
import "../interfaces/external/INonfungiblePositionManager.sol";
import "../interfaces/ILPFeeReceiver.sol";

contract ARC is ERC20, IERC721Receiver, Ownable, ReentrancyGuard {
    error TokenIdNotSet();

    address public immutable WETH;
    IWETH9 public immutable weth;
    INonfungiblePositionManager public immutable nonfungiblePositionManager;
    ILPFeeReceiver public lpFeeReceiver;

    uint256 public tokenId;

    uint256 public amount0Collected;
    uint256 public amount1Collected;

    event FeesCollected(uint256 indexed _amount0, uint256 indexed _amount1, address _lpFeeReceiver, uint256 indexed _timestamp);

    constructor (address _WETH, address _nonfungiblePositionManager, address _lpFeeReceiver) ERC20("Arcadeum", "ARC") {
        WETH = _WETH;
        weth = IWETH9(_WETH);
        nonfungiblePositionManager = INonfungiblePositionManager(_nonfungiblePositionManager);
        lpFeeReceiver = ILPFeeReceiver(_lpFeeReceiver);
        _mint(_msgSender(), 10000000 * (10**18));
    }

    function claim() external nonReentrant {
        if (tokenId == 0) {
            revert TokenIdNotSet();
        }

        (uint256 _amount0, uint256 _amount1) = nonfungiblePositionManager.collect(INonfungiblePositionManager.CollectParams({
            tokenId: tokenId,
            recipient: address(this),
            amount0Max: type(uint128).max,
            amount1Max: type(uint128).max
        }));

        _burn(address(this), _amount0);
        weth.withdraw(_amount1);

        lpFeeReceiver.depositYield{value: address(this).balance}();

        amount0Collected += _amount0;
        amount1Collected += _amount1;
        emit FeesCollected(_amount0, _amount1, address(lpFeeReceiver), block.timestamp);
    }

    function burnFrom(address account, uint256 amount) public virtual {
        _spendAllowance(account, _msgSender(), amount);
        _burn(account, amount);
    }

    function setLPFeeReceiver(address _lpFeeReceiver) external nonReentrant onlyOwner {
        lpFeeReceiver = ILPFeeReceiver(_lpFeeReceiver);
    }

    function setTokenId(uint256 _tokenId) external nonReentrant onlyOwner {
        tokenId = _tokenId;
    }

    function getLPFeeReceiver() external view returns (address) {
        return address(lpFeeReceiver);
    }

    function getTokenId() external view returns (uint256) {
        return tokenId;
    }

    function getAmount0Collected() external view returns (uint256) {
        return amount0Collected;
    }

    function getAmount1Collected() external view returns (uint256) {
        return amount1Collected;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    receive() external payable {}
}
