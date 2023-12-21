//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import {ERC20} from "openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC165} from "openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IMugen} from "../interfaces/IMugen.sol";
import "./OFTCore.sol";

/// @title Mugen
/// @author Mugen Dev
/// @notice ERC20 implementation ontop of Layer Zero
/// @notice Ownable is inherited through OFTCore
/// which needs to be maintained either with a governance system or
/// multisig in order to update its Layer Zero configurations.

contract Mugen is OFTCore, ERC20, IMugen {
    error NotOwner();
    error MinterSet();

    /// @notice address who is available to mint tokens, set to the treasury
    /// in order to implement the bonding curve.

    address public minter;

    constructor(address _lzEndpoint)
        ERC20("Mugen", "MGN")
        OFTCore(_lzEndpoint)
    {}

    function mint(address _to, uint256 _amount) external override onlyMinter {
        _mint(_to, _amount);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(OFTCore, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(IMugen).interfaceId ||
            interfaceId == type(IERC20).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function circulatingSupply()
        public
        view
        virtual
        override
        returns (uint256)
    {
        return totalSupply();
    }

    function _debitFrom(
        address _from,
        uint16,
        bytes memory,
        uint256 _amount
    ) internal virtual override {
        address spender = _msgSender();
        if (_from != spender) {
            _spendAllowance(_from, spender, _amount);
        }
        _burn(_from, _amount);
    }

    function _creditTo(
        uint16,
        address _toAddress,
        uint256 _amount
    ) internal virtual override {
        _mint(_toAddress, _amount);
    }

    function setMinter(address _minter) external onlyOwner {
        minter = _minter;
    }

    modifier onlyMinter() {
        require(
            msg.sender == minter || msg.sender == owner(),
            "Only minter can call this"
        );
        _;
    }
}
