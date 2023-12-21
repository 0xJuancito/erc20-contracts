// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@layerzerolabs/solidity-examples/contracts/token/oft/OFT.sol";

contract StoneCross is OFT {
    using BytesLib for bytes;

    uint256 public constant DAY_INTERVAL = 24 * 60 * 60;

    uint16 public constant PT_FEED = 1;
    uint16 public constant PT_SET_ENABLE = 2;
    uint16 public constant PT_SET_CAP = 3;

    uint256 public tokenPrice = 1e18;
    uint256 public cap;
    uint256 public updatedTime;

    mapping(uint256 => uint256) public quota;

    bool public enable = true;

    constructor(
        address _layerZeroEndpoint,
        uint256 _cap
    ) OFT("StakeStone Ether", "STONE", _layerZeroEndpoint) {
        updatedTime = block.timestamp;
        cap = _cap;
    }

    function sendFrom(
        address _from,
        uint16 _dstChainId,
        bytes calldata _toAddress,
        uint _amount,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes calldata _adapterParams
    ) public payable override(IOFTCore, OFTCore) {
        require(enable, "invalid");

        uint256 id;
        assembly {
            id := chainid()
        }
        require(id != _dstChainId, "same chain");

        uint256 day = block.timestamp / DAY_INTERVAL;
        require(_amount + quota[day] <= cap, "Exceed cap");

        quota[day] = quota[day] + _amount;

        super.sendFrom(
            _from,
            _dstChainId,
            _toAddress,
            _amount,
            _refundAddress,
            _zroPaymentAddress,
            _adapterParams
        );
    }

    function _nonblockingLzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload
    ) internal virtual override {
        uint16 packetType;
        assembly {
            packetType := mload(add(_payload, 32))
        }

        if (packetType == PT_SEND) {
            _sendAck(_srcChainId, _srcAddress, _nonce, _payload);
        } else if (packetType == PT_FEED) {
            (, bytes memory toAddressBytes, uint256 price, uint256 time) = abi
                .decode(_payload, (uint16, bytes, uint256, uint256));

            address to = toAddressBytes.toAddress(0);
            require(to == address(this), "not this contract");
            require(time > updatedTime, "stale price");

            tokenPrice = price;
            updatedTime = time;
        } else if (packetType == PT_SET_ENABLE) {
            (, bytes memory toAddressBytes, bool flag) = abi.decode(
                _payload,
                (uint16, bytes, bool)
            );

            address to = toAddressBytes.toAddress(0);
            require(to == address(this), "not this contract");

            enable = flag;
        } else if (packetType == PT_SET_CAP) {
            (, bytes memory toAddressBytes, uint256 _cap) = abi.decode(
                _payload,
                (uint16, bytes, uint256)
            );

            address to = toAddressBytes.toAddress(0);
            require(to == address(this), "not this contract");

            cap = _cap;
        } else {
            revert("unknown packet type");
        }
    }

    function getQuota() external returns (uint256) {
        uint256 amount = quota[block.timestamp / DAY_INTERVAL];
        if (cap > amount && enable) {
            return cap - amount;
        }
    }
}
