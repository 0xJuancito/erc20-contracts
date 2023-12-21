//SPDX-License-Identifier: MIT
pragma solidity 0.7.3;

import "@openzeppelin/contracts/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title bloXmove ERC20 Contract.
 */
contract BloXmoveToken is ERC20, ERC165 {
    using SafeMath for uint256;

    /**
    * @dev mint the tokens, register the ERC20 interface.
    * The total supply on $BLXM tokens on BSC is 30,000,000 tokens
    * Previously 50 million $BLXM tokens were deployed on Ethereum
    * TX ID: 0xdec71976f80fa74989b3e09699852d76dbe2b782acff2ab0fb35562705aa448d
    * Then 30 million $BLXM tokens were burned on Ethereum
    * TX ID: 0xf15f37cfc1b3596370031fab9124654c288d3b084baad5918698cf681b62a128
    *
    * @param _grantsManagerAddr the address of the multi-sig wallet responsible for add Grants in the Vesting contract.
    * @param _foundationAddr the address of the wallet responsible for market making.
    * @param _publicSaleAddr the address of the multi-sig wallet responsible for public sale.
    * @param _grantsSupply the amount of token to be locked as Grants to private investors
    * @param _marketmakingSupply the amount of token for the market making
    * @param _publicSaleSupply the amount of token for the public sale
    *
    * Emits a {Transfer} event three times.
    */
    constructor(
        address _grantsManagerAddr,
        address _foundationAddr,
        address _publicSaleAddr,
        uint256 _grantsSupply,
        uint256 _marketmakingSupply,
        uint256 _publicSaleSupply
    ) ERC20("bloXmove Token", "BLXM") {
        require(
            _grantsSupply.add(_marketmakingSupply).add(_publicSaleSupply) ==
                30000000000000000000000000,
            "ERC20: Wrong total supply"
        );
        _mint(_grantsManagerAddr, _grantsSupply);
        _mint(_foundationAddr, _marketmakingSupply);
        _mint(_publicSaleAddr, _publicSaleSupply);
        _registerInterface(type(IERC20).interfaceId);
        _registerInterface(ERC20.name.selector);
        _registerInterface(ERC20.symbol.selector);
        _registerInterface(ERC20.decimals.selector);
    }

    /**
     * @dev Not supported receive function.
     */
    receive() external payable {
        revert("Not supported receive function");
    }

    /**
     * @dev Not supported fallback function.
     */
    fallback() external payable {
        revert("Not supported fallback function");
    }

    /**
     * @dev Bulk transfer which gets an array of addresses and an array of values to transfer.
     * @param _to the array of addresses receiving the transfers
     * @param _values the amount of tokens (unit 1/18) for each transfer
     *
     * Requirements:
     *
     * - Both arrays have equal length
     * - Inherits the requirements from the transfer function
     *
     * @return true after finishing all transfers successfully.
     */
    function bulkTransfer(address[] calldata _to, uint256[] calldata _values)
        external
        returns (bool)
    {
        require(_to.length == _values.length, "Not the same length");
        for (uint256 i = 0; i < _to.length; i++) {
            require(transfer(_to[i], _values[i]), "Transfer Error");
        }
        return true;
    }
}
