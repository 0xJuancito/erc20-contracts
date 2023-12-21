pragma solidity 0.8.19;
// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VKAToken is ERC20Burnable, Ownable {
    uint256 public constant supply = 100_000_000e18;
    mapping(address => bool) public isRecipientAllowed;
    bool public isSwapEnabled = false;

    constructor() ERC20("VKA", "VKA") {
        _mint(msg.sender, supply);
    }

    function setRecipientAllowed(
        address _handler,
        bool _status
    ) external onlyOwner {
        isRecipientAllowed[_handler] = _status;
    }

    function enableSwap() external onlyOwner {
        require(isSwapEnabled == false, "Swap already enabled");
        isSwapEnabled = true;
    }

    function transfer(
        address to,
        uint256 value
    ) public override returns (bool) {
        address owner = _msgSender();
        if (isSwapEnabled) {
            _transfer(owner, to, value);
            return true;
        } else {
            return _transferWithValidation(owner, to, value);
        }
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public override returns (bool) {
        address spender = _msgSender();
        if (isSwapEnabled) {
            _spendAllowance(from, spender, value);
            _transfer(from, to, value);
            return true;
        } else {
            _spendAllowance(from, spender, value);
            return _transferWithValidation(from, to, value);
        }
    }

    function _transferWithValidation(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        require(
            sender == owner() ||
                recipient == owner() ||
                isRecipientAllowed[recipient],
            "VKA: transfer not allowed"
        );
        _transfer(sender, recipient, amount);

        return true;
    }
}
