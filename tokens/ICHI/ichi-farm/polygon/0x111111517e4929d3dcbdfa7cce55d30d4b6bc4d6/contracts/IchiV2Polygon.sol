// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract IchiV2Polygon is ERC20, Ownable {
    using SafeMath for uint256;

    // Polygon's ChildChainManager contract, only entity allowed to mint
    address public childChainManagerProxy;

    constructor(
        string memory name,
        string memory symbol,
        address _childChainManagerProxy,
        address owner
    ) Ownable() ERC20(name, symbol) {
        childChainManagerProxy = _childChainManagerProxy;
        transferOwnership(owner);

        // no minting done here
        // tokens are minted on mainnet and later bridged through Polygon's PoS bridge
    }

    // being proxified smart contract, most probably childChainManagerProxy contract's address
    // is not going to change ever, but still, lets keep it
    function updateChildChainManager(address newChildChainManagerProxy)
        external
        onlyOwner
    {
        require(
            newChildChainManagerProxy != address(0),
            "Bad ChildChainManagerProxy address"
        );

        childChainManagerProxy = newChildChainManagerProxy;
    }

    function deposit(address user, bytes calldata depositData) external {
        require(
            msg.sender == childChainManagerProxy,
            "You're not allowed to deposit"
        );

        uint256 amount = abi.decode(depositData, (uint256));

        _mint(user, amount);
    }

    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
