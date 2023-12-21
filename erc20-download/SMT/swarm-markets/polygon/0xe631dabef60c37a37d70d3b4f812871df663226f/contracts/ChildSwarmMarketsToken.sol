//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ChildSwarmMarketsToken is ERC20, Ownable
{
    using SafeMath for uint256;
    // keeping it for checking, whether deposit being called by valid address or not
    address public childChainManagerProxy;
    address public deployer;
    string public KYA;

    constructor(address _childChainManagerProxy) 
        ERC20("Swarm Markets", "SMT") 
        Ownable() {
        //"Swarm Markets", "SMT", 250000000 * 10**18, owner
        _setupDecimals(18);
        childChainManagerProxy = _childChainManagerProxy;
        deployer = msg.sender;

        // Can't mint here, because minting in child chain smart contract's constructor not allowed
        //
        // In case of mintable tokens it can be done, there can be external mintable function too
        // which can be called by some trusted parties
        // _mint(msg.sender, 10 ** 27);
    
    }

    // being proxified smart contract, most probably childChainManagerProxy contract's address
    // is not going to change ever, but still, lets keep it 
    function updateChildChainManager(address newChildChainManagerProxy) external {
        require(newChildChainManagerProxy != address(0), "Bad ChildChainManagerProxy address");
        require(msg.sender == deployer, "You're not allowed");

        childChainManagerProxy = newChildChainManagerProxy;
    }

    function deposit(address user, bytes calldata depositData) external {
        require(msg.sender == childChainManagerProxy, "You're not allowed to deposit");

        uint256 amount = abi.decode(depositData, (uint256));
        // `amount` token getting minted here & equal amount got locked in RootChainManager
        super._mint(user, amount);
    }

    function withdraw(uint256 amount) external {
        super._burn(msg.sender, amount);
    }

    function setKYA(string calldata _knowYourAsset) external onlyOwner {
        KYA = _knowYourAsset;
    }
}