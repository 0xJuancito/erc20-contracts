// SPDX-License-Identifier: MIT

//** LFG ERC20 TOKEN */
//** Author Alex Hong : LFG NFT Platform 2021.9 */

pragma solidity 0.6.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

abstract contract BPContract {
    function protect(
        address sender,
        address receiver,
        uint256 amount
    ) external virtual view;
}

contract LFGToken is ERC20, Ownable {
    using SafeMath for uint256;

    address public constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    BPContract public BP;
    bool public bpEnabled;
    bool public BPDisabledForever = false;

    /**
     *
     * @dev mint initialSupply in constructor with symbol and name
     *
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address owner
    ) public ERC20(name, symbol) {
        require(owner != address(0), "Invalid owner address");
        _mint(owner, initialSupply);
        transferOwnership(owner);
    }

    /**
     *
     * @dev lock tokens by sending to DEAD address
     *
     */
    function lockTokens(uint256 amount) external onlyOwner returns (bool) {
        _transfer(_msgSender(), DEAD_ADDRESS, amount);
        return true;
    }

    function setBPAddress(address _bp) external onlyOwner {
        require(_bp != address(0), "Invalid address");
        BP = BPContract(_bp);
    }

    function setBpEnabled(bool _enabled) external onlyOwner {
        bpEnabled = _enabled;
    }

    function setBotProtectionDisableForever() external onlyOwner {
        require(BPDisabledForever == false);
        BPDisabledForever = true;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        if (bpEnabled && !BPDisabledForever) {
            BP.protect(from, to, amount);
        }
    }

    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) external onlyOwner returns (bool) {
        _burn(_msgSender(), amount);
        return true;
    }
}
