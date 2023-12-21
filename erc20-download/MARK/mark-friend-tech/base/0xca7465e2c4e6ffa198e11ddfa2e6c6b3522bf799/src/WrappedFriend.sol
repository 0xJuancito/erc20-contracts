// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.21;

import {ERC20} from "solady/src/tokens/ERC20.sol";

import {IFriendtechSharesV1} from "./interfaces/IFriendTech.sol";

contract WrappedFriend is ERC20 {
    IFriendtechSharesV1 public constant FRIENDTECH = IFriendtechSharesV1(0xCF205808Ed36593aa40a44F10c7f7C2F67d4A4d4);
    uint256 public constant MULTIPLIER = 100;

    address public target;
    address public immutable factory;

    string internal _name = "WrappedFriend";
    string internal _symbol = "WF";

    constructor() {
        factory = msg.sender;
    }

    function initialize(address _target) external {
        require(msg.sender == factory, "auth");
        target = _target;
    }

    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                          MINT & BURN
    //////////////////////////////////////////////////////////////*/

    function mint(uint256 shares) external payable returns (uint256 refund) {
        uint256 cost = FRIENDTECH.getBuyPriceAfterFee(target, shares);
        require(msg.value >= cost, "WrappedFriend: not enough eth");
        FRIENDTECH.buyShares{value: cost}(target, shares);
        _mint(msg.sender, shares * MULTIPLIER * 1e18);
        // Refund excess
        refund = msg.value - cost;
        if (refund > 0) {
            msg.sender.call{value: refund}("");
        }
    }

    function burn(address from, uint256 shares) external returns (uint256 proceeds) {
        require(from == msg.sender || msg.sender == factory, "auth");
        _burn(from, shares * MULTIPLIER * 1e18);
        FRIENDTECH.sellShares(target, shares);
        proceeds = address(this).balance;
        msg.sender.call{value: address(this).balance}("");
    }

    /*//////////////////////////////////////////////////////////////
                            NAMING
    //////////////////////////////////////////////////////////////*/

    function setNameAndSymbol(string memory __name, string memory __symbol) external {
        require(msg.sender == target, "auth");
        _name = __name;
        _symbol = __symbol;
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }
}
