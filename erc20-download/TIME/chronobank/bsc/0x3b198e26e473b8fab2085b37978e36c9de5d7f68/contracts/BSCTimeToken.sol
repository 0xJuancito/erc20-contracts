// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20.sol";
import "./interfaces/IERC677.sol";
import "./interfaces/IERC677Receiver.sol";
import "./Validators.sol";

contract TimeToken is ERC20, IERC677, Validators {

    event Minted(address indexed _from, uint256 indexed _fromChainId, uint256 indexed _lockId, uint256 _amount);
    event Burned(address indexed _from, uint256 indexed _toChainId, uint256 indexed _burnId, uint256 _amount);

    uint256 public lastBurnId;
    mapping(uint256 =>  mapping(uint256 => bool)) public lockIdsUsed;

    constructor(
        string memory tokenName,
        string memory tokenSymbol
    ) ERC20(tokenName, tokenSymbol) {}

    function mint (uint256 _fromChainId, uint256 _lockId, uint256 _amount, bytes[] memory _signatures) external {
        require(!lockIdsUsed[_fromChainId][_lockId], "Lock id already used");
        bytes32 messageHash = keccak256(abi.encodePacked(_msgSender(), _fromChainId, block.chainid, _lockId, _amount));
        require(checkSignatures(messageHash, _signatures), "Incorrect signature(s)");
        lockIdsUsed[_fromChainId][_lockId] = true;
        _mint(_msgSender(), _amount);
        emit Minted(_msgSender(), _fromChainId, _lockId, _amount);
    }

    function burn (uint256 _toChainId, uint256 _amount) external {
        require(_amount > 0, "The amount of the lock must not be zero");
        (bool found,) = indexOfChainId(_toChainId);
        require(found, "ChainId not allowed");
        _burn(_msgSender(), _amount);
        lastBurnId++;
        emit Burned(_msgSender(), _toChainId, lastBurnId, _amount);
    }

    function transferAndCall(address _to, uint _value, bytes memory _data) public override returns (bool success)
    {
        transfer(_to, _value);
        emit Transfer(_msgSender(), _to, _value, _data);
        if (isContract(_to)) {
            contractFallback(_to, _value, _data);
        }
        return true;
    }

    function contractFallback(address _to, uint _value, bytes memory _data) private
    {
        IERC677Receiver receiver = IERC677Receiver(_to);
        receiver.onTokenTransfer(_msgSender(), _value, _data);
    }

    function isContract(address _addr) private view returns (bool hasCode)
    {
        uint length;
        assembly { length := extcodesize(_addr) }
        return length > 0;
    }

}
