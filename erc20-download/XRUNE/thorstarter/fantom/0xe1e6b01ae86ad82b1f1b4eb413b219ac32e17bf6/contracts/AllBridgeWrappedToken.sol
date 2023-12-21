// SPDX-License-Identifier: Apache 2
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IERC677.sol";
import "./interfaces/IERC677Receiver.sol";

contract WrappedToken is Context, Ownable, ERC20, IERC677 {
    uint8 private _decimals;
    bytes4 public source;
    bytes32 public sourceAddress;

    constructor(
        bytes4 source_,
        bytes32 sourceAddress_,
        uint8 decimals_,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {
        source = source_;
        sourceAddress = sourceAddress_;
        _decimals = decimals_;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) public virtual onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public virtual onlyOwner {
        _burn(from, amount);
    }

    /**
    * @dev transfer token to a contract address with additional data if the recipient is a contact.
    * @param _to The address to transfer to.
    * @param _value The amount to be transferred.
    * @param _data The extra data to be passed to the receiving contract.
    */
    function transferAndCall(address _to, uint _value, bytes calldata _data)
        public
        override
        returns (bool success)
    {
        super.transfer(_to, _value);
        emit TransferWithData(msg.sender, _to, _value, _data);
        if (isContract(_to)) {
            contractFallback(_to, _value, _data);
        }
        return true;
    }

    function contractFallback(address _to, uint _value, bytes calldata _data)
        private
    {
        IERC677Receiver receiver = IERC677Receiver(_to);
        receiver.onTokenTransfer(msg.sender, _value, _data);
    }

    function isContract(address _addr)
        private
        view
        returns (bool hasCode)
    {
        uint length;
        assembly { length := extcodesize(_addr) }
        return length > 0;
    }
}