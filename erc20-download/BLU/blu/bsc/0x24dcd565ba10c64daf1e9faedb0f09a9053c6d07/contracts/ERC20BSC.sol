// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @dev ERC-20 Token
 */
contract BLU is ERC20, Ownable {
    using SafeERC20 for IERC20;

    event TransferERC20(
        address indexed owner,
        address indexed token,
        address indexed to,
        uint256 amount
    );

    /**
     * @dev Initializes the contract.
     */
    constructor(string memory _name, string memory _symbol, uint256 _totalSupply, address _owner) ERC20(_name, _symbol) {
        _mint(_owner, _totalSupply * 10 ** decimals());
        _transferOwnership(_owner);
    }

    /**
     * @notice Transfer ERC-20 tokens from contract to an address
     * @dev Only owner can transfer tokens
     * @param _token The token contract address
     * @param _to The recipient address
     * @param _amount The amount to transfer
     */
    function withdrawERC20FromContract(
        address _token,
        address _to,
        uint256 _amount
    ) external onlyOwner {
        IERC20(_token).safeTransfer(_to, _amount);

        emit TransferERC20(msg.sender, _token, _to, _amount);
    }
}
