// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "Ownable.sol";
import "ERC20.sol";


/// @title XYToken is the XY Finance governance token
contract XYToken is ERC20, Ownable {

    /// @dev This contract should be deployed on all periphery chains.
    ///   - On Ethereum, `amount` is set to `100,000,000 * 1e18` and `renounceOwnership` should be called right after the contract is deployed, to make sure the cap is `100,000,000 * 1e18`.
    ///   - On other chains, `amount` is set to `0`. The contract is served as a XY Token bridge through mint-and-burn.
    /// @param name XY Token name
    /// @param symbol XY Token symbol
    /// @param vault Address where initial `amount` XY Token is sent
    /// @param amount Amount of XY Token is minted when the contract is deployed
    constructor(string memory name, string memory symbol, address vault, uint256 amount) ERC20(name, symbol) {
        _mint(vault, amount);
    }

    mapping (address => bool) public isMinter;

    modifier onlyMinter {
        require(isMinter[msg.sender], "ERR_NOT_MINTER");
        _;
    }

    function setMinter(address minter, bool _isMinter) external onlyOwner {
        isMinter[minter] = _isMinter;

        emit SetMinter(minter, _isMinter);
    }

    function mint(address account, uint256 amount) external onlyMinter {
        _mint(account, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    event SetMinter(address minter, bool isMinter);
}
