// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Context.sol";

import "./commons/BotPrevent.sol";

contract WanakaFarm is ERC20, ERC20Burnable, Ownable {
    BPContract public BP;
    bool public bpEnabled;
    uint256 private constant INITIAL_SUPPLY = 500 * 10**(6 + 18); // 500M tokens

    event BPAdded(address indexed bp);
    event BPEnabled(bool indexed _enabled);
    event BPTransfer(address from, address to, uint256 amount);

    constructor(
        address _owner,
        string memory _tokenName,
        string memory _tokenSymbol
    ) public ERC20(_tokenName, _tokenSymbol) {
        _mint(_owner, INITIAL_SUPPLY);
        transferOwnership(_owner);
    }

    function setBpAddress(address _bp) external onlyOwner {
        require(address(BP) == address(0), "Can only be initialized once");
        BP = BPContract(_bp);

        emit BPAdded(_bp);
    }

    function setBpEnabled(bool _enabled) external onlyOwner {
        require(address(BP) != address(0), "You have to set BP address first");
        bpEnabled = _enabled;
        emit BPEnabled(_enabled);
    }

    /**
     * @dev Add the BP handler to prevents the bots.
     *
     **/
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        if (bpEnabled) {
            BP.protect(sender, recipient, amount);
            emit BPTransfer(sender, recipient, amount);
        }
        super._transfer(sender, recipient, amount);
    }
}
