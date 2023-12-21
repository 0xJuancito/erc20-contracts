// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../types/PetroAccessControl.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';




contract OIL is ERC20Upgradeable, PetroAccessControl{

    address V3router;
    address V3factory;

    IUniswapV3Factory factory;

    address pool001;
    address pool005;
    address pool03;
    address pool1;


    function initialize() initializer public {
        __ERC20_init("OIL", "OIL");
        __PetroAccessControl_init();
        _mint(msg.sender, 920_000 * 1 ether);
        
        V3router = address(0xE592427A0AEce92De3Edee1F18E0157C05861564);
        V3factory = address(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    }

    mapping(address => uint) public betaClaimed;
    mapping(address => bool) public betaTester;

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {

        if(from != DevWallet && from != address(0) && from != RefineryAddress && from != PetroMapAddress && from != RewardManagerAddress) // PETROSALE
        {
            require(to == PetroMapAddress || to == RewardManagerAddress, "Not allowed to transfer");
        }
        super._beforeTokenTransfer(from, to, amount);
    }

    function mint(address _account, uint256 _amount) public onlyRole(REFINERY_ROLE) {
        _mint(_account, _amount);
    }

    function burn(uint256 _amount) public {
        _burn(msg.sender, _amount);
    }

    function delegatedApprove(address _user, address _spender, uint256 _amount) public onlyRole(GAME_MANAGER) {
        _approve(_user,_spender,_amount);
    }

    uint256[45] private __gap;
}
