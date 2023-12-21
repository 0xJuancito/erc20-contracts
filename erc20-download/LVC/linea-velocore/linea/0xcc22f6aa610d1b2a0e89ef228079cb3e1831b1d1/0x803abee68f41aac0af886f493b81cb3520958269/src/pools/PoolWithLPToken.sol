// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "src/interfaces/IVault.sol";
import "src/lib/Token.sol";
import "./Pool.sol";

/**
 * @dev a base contract for pools with single ERC20 lp token.
 *
 * Two notable features:
 * <1>
 * Inspired by composable pools of Balancer, it mints MAX_SUPPLY tokens to the vault on initialization, allowing this pool to 'mint' lp tokens from velocore__execute().
 * However, the initial mint only happens in vault's perspective; balanceOf() and totalSupply() is customized to trick the vault into thinking it has MAX_SUPPLY tokens.
 * when msg.sender != vault, the view functions behave normally.
 *
 * <2>
 * the vault has max allowance on every addresses by default, and this can't be changed.
 */
abstract contract PoolWithLPToken is Pool, IERC20 {
    uint128 constant MAX_SUPPLY = uint128(type(uint112).max);
    string public name;

    string public symbol;

    mapping(address => uint256) _balanceOf;

    mapping(address => mapping(address => uint256)) _allowance;

    function _initialize(string memory name_, string memory symbol_) internal {
        name = name_;
        symbol = symbol_;
        _mintVirtualSupply();
    }

    function _mintVirtualSupply() internal {
        _balanceOf[address(vault)] = MAX_SUPPLY;
        vault.notifyInitialSupply(toToken(this), 0, MAX_SUPPLY); // this sets pool balances to the given value.
    }

    /**
     * @dev due to the mechanism of 'minting' by transferring, mint and burn events behave weirdly.
     * this function should be called whenever new tokens are created by transferring.
     * these simulate minting and burning from/to the vault.
     */
    function _simulateMint(uint256 amount) internal {
        emit Transfer(address(0), address(vault), amount);
    }

    function _simulateBurn(uint256 amount) internal {
        emit Transfer(address(vault), address(0), amount);
    }

    /**
     * @dev vault balance is subtracted by pool balance to behave "normally"
     */
    function balanceOf(address addr) external view returns (uint256) {
        if (msg.sender != address(vault) && addr == address(vault)) {
            unchecked {
                return _balanceOf[addr] - _getPoolBalance(toToken(this));
            }
        }
        return _balanceOf[addr];
    }

    function decimals() external view virtual returns (uint8) {
        return 18;
    }

    function allowance(address from, address spender) external view returns (uint256) {
        return (spender == address(vault)) ? type(uint256).max : _allowance[from][spender];
    }

    /**
     * @dev subtracted by pool balance to behave "normally"
     */
    function totalSupply() public view virtual returns (uint256) {
        return MAX_SUPPLY - _getPoolBalance(toToken(this));
    }

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        _allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function increaseAllowance(address _spender, uint256 _addedValue) public returns (bool) {
        approve(_spender, _allowance[msg.sender][_spender] + _addedValue);
        return true;
    }

    function decreaseAllowance(address _spender, uint256 _subtractedValue) public returns (bool) {
        approve(_spender, _allowance[msg.sender][_spender] - _subtractedValue);
        return true;
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        _balanceOf[msg.sender] -= amount;
        unchecked {
            _balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual returns (bool) {
        if (msg.sender != address(vault)) {
            uint256 allowed = _allowance[from][msg.sender];

            if (allowed != type(uint256).max) _allowance[from][msg.sender] = allowed - amount;
        }
        _balanceOf[from] -= amount;

        unchecked {
            _balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }
}
