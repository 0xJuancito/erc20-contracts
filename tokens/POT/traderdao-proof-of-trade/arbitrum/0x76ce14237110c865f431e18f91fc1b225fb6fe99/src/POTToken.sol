// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract POTToken is ERC20, ERC20Burnable, Pausable, Ownable {
    using ECDSA for bytes32;

    uint8 private _decimals;
    mapping(bytes32 => bool) public _swapKey;
    mapping(address => uint256) public AmountToMint;
    address private _signerAddress = 0x75ffe67F97D9259c08A8a3F192625752AEE66269;

    event MintCompleted(address indexed to, uint256 value, string _data);

    constructor() ERC20("POT Token", "POT") {
        _decimals = 18;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function SetSigner(address _address) external onlyOwner {
        _signerAddress = _address;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    /**
     * @dev Creates `amount` tokens and assigns them to `msg.sender`, increasing
     * the total supply.
     *
     * Requirements
     *
     * - `msg.sender` must be the token owner
     */
    function mint(
        string calldata timestamp_,
        bytes calldata signature_,
        uint256 amount_
    ) public returns (bool) {
        bytes32 message = getMessage(timestamp_, amount_, address(this), msg.sender);
        require(!_swapKey[message], "Key Already Claimed");
        require(isValidData(message, signature_), "Invalid Signature");
        require(amount_ > 0, "Invalid fund");
        _swapKey[message] = true;
        _mint(_msgSender(), amount_);

        emit MintCompleted(
            msg.sender,
            amount_,
            string.concat(
                string.concat(timestamp_, Strings.toString(amount_)),
                Strings.toHexString(uint256(uint160(msg.sender)), 20)
            )
        );

        return true;
    }

    function ownerMint(uint256 amount) public onlyOwner {
        _mint(_msgSender(), amount);
    }

    function getMessage(
        string calldata timestamp_,
        uint256 amount_,
        address contractAddress_,
        address msgSender_
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(timestamp_, amount_, contractAddress_, msgSender_));
    }

    function isValidData(
        bytes32 message_,
        bytes memory signature_
    ) public view returns (bool) {
        return
            message_.toEthSignedMessageHash().recover(signature_) ==
            _signerAddress;
    }

    function toByte(uint8 _uint8) public pure returns (bytes1) {
        if (_uint8 < 10) {
            return bytes1(_uint8 + 48);
        } else {
            return bytes1(_uint8 + 87);
        }
    }
}