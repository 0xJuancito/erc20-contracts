// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Token is ERC20Burnable, ReentrancyGuard, Ownable {
    using SafeMath for uint256;

    uint256 private constant MAX_SUPPLY = 10000 * (10 ** 18);

    mapping(address => bool) private frees;
    mapping(address => uint256) private swaps;
    uint256 constant X = 1000000;
    // 3000: 0.3%, 100: 0.01%, 50000: 5%

    constructor(address account) ERC20('Punk X', 'Punk') {
        _mint(account, MAX_SUPPLY);
    }

    function setSwapFee(address _swap, uint256 _fee) public onlyOwner {
        require(_swap != address(0), 'zero');
        require(_swap != address(this), 'this');
        require(_fee <= 500000, 'Max fee: 50%');
        swaps[_swap] = _fee;
    }

    function setFree(address _free, bool isFree) public onlyOwner {
        require(_free != address(0), 'zero');
        require(address(_free) != address(this), 'this');
        if (isFree) {
            require(!frees[_free], 'exist');
            frees[_free] = true;
        } else {
            require(frees[_free], 'not exist');
            frees[_free] = false;
        }
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(amount > 0, "amount gt 0");
        if (swaps[to] == 0 || frees[from]) {
            super._transfer(from, to, amount);
            return;
        }
        if (swaps[to] > 0) {
            // Sell
            uint256 _fee = amount.mul(swaps[to]).div(X);
            _burn(from, _fee);
            super._transfer(from, to, amount.sub(_fee));
            return;
        }
    }
}
