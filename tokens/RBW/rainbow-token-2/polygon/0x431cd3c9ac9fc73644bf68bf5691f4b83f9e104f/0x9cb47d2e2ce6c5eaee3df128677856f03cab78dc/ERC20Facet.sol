// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "ERC20WithCommonStorage.sol";
import "LibERC20.sol";
import "LibDiamond.sol";

/*
    Implementation of Erc20 with Diamond storage with some modifications
    https://github.com/bugout-dev/dao/blob/main/contracts/moonstream/ERC20WithCommonStorage.sol
 */
contract ERC20Facet is ERC20WithCommonStorage {
    constructor() {}

    function contractController() external view returns (address) {
        return LibERC20.erc20Storage().controller;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        require(
            recipient != address(this),
            "ERC20Facet: You can't send RBW to the contract itself. In order to burn, use burn()"
        );
        super.transferFrom(sender, recipient, amount);
        return true;
    }

    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        require(
            recipient != address(this),
            "ERC20Facet: You can't send RBW to the contract itself. In order to burn, use burn()"
        );
        super.transfer(recipient, amount);
        return true;
    }
}
