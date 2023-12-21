// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

import "../library/ERC2771ContextUpdateable.sol";
import "../library/FlowLimiter.sol";

interface IMintableBurnableToken {
    function burn(uint256 amount) external;

    function mint(address to, uint256 amount) external;

    function transfer(address recipient, uint256 amount) external returns (bool);

    // function transferFrom(
    //     address sender,
    //     address recipient,
    //     uint256 amount
    // ) external returns (bool);
}

/**
 * @dev Anyswap router adapter, written by IF. Compatible with Anyswap Router V4 and V5.
 *
 *      For reference:
 *          Anyswap ERC20 (which this adapter replaces): https://github.com/connext/chaindata/blob/main/AnyswapV5ERC20.sol
 *          Anyswap V5 Router: https://github.com/anyswap/anyswap-v1-core/blob/master/contracts/AnyswapV5Router.sol
 */
/* solhint-disable not-rely-on-time */
contract IFAnyswapRouterAdapter is ERC20, ERC20Permit, ERC2771ContextUpdateable, FlowLimiter {
    using SafeERC20 for ERC20;

    // CONSTS

    // router role
    bytes32 public constant ROUTER_ROLE = keccak256("ROUTER_ROLE");
    // burn address used in case `burn` is not callable on underlying token contract
    address public constant FALLBACK_BURN_ADDRESS = address(0xDEAD);

    // VARS

    // underlying currency
    address public immutable underlying;

    // underlying currency that bridge mints on destination chain
    // if not set, then uses `underlying`
    address public underlyingBridgeOut;

    // if true, then operate in locking mode, else operate in mint-burn mode
    bool public lockElseMintBurn;

    // EVENTS

    event SetUnderlyingBridgeOut(address indexed underlyingBridgeOut);
    event SetMode(bool indexed lockElseMintBurn);
    event MintAdapterToken(address indexed to, uint256 amount);
    event WithdrawAccumulated(address indexed sender, uint256 amount);
    event EmergencyTokenRetrieve(address indexed sender, uint256 amount);

    // constructor
    constructor(
        string memory _name,
        string memory _symbol,
        address _underlying,
        address admin
    ) ERC20(_name, _symbol) ERC20Permit(_name) {
        require(_underlying != address(0x0) && _underlying != address(this), "Underlying invalid");

        underlying = _underlying;

        _setupRole(DEFAULT_ADMIN_ROLE, admin);
    }

    //// admin

    // for setting underlying token on bridge out operation
    function setUnderlyingBridgeOut(address _underlyingBridgeOut) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Must have admin role");

        require(underlyingBridgeOut == address(0x0), "Address already set");
        underlyingBridgeOut = _underlyingBridgeOut;

        // emit
        emit SetUnderlyingBridgeOut(underlyingBridgeOut);
    }

    // for setting bridge adapter mode
    function setMode(bool _lockElseMintBurn) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Must have admin role");

        lockElseMintBurn = _lockElseMintBurn;

        // emit
        emit SetMode(_lockElseMintBurn);
    }

    // provide a separate function for minting the adapter token specifically
    function mintAdapterToken(address to, uint256 amount) external returns (bool) {
        require(hasRole(ROUTER_ROLE, _msgSender()), "Must have router role");

        // mint adapter token
        _mint(to, amount);

        // emit
        emit MintAdapterToken(to, amount);

        // returns bool for consistency with anyswap spec
        return true;
    }

    // admin function to withdraw accumulated token
    function withdrawAccumulated() external returns (uint256) {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Must have admin role");

        // get balance of token
        uint256 tokenBalance = ERC20(underlying).balanceOf(address(this));
        // transfer all
        ERC20(underlying).safeTransfer(_msgSender(), tokenBalance);

        // emit
        emit WithdrawAccumulated(_msgSender(), tokenBalance);

        return tokenBalance;
    }

    //// fns called by router

    // transferring onto bridge (called on source chain)
    // to support anySwapOutUnderlying
    function depositVault(uint256 amount, address to) external virtual returns (uint256) {
        require(hasRole(ROUTER_ROLE, _msgSender()), "Must have router role");

        // consume flow quota (rate limit)
        consumeQuotaOfUser(to, FlowDirection.OUT, amount);
        // mint adapter token
        _mint(to, amount);

        // if burn, also include a burn of underlying token
        if (!lockElseMintBurn) {
            // burn underlying
            /* solhint-disable-next-line no-empty-blocks */
            try IMintableBurnableToken(underlying).burn(amount) {
                // burned via token's `burn` function
            } catch {
                /* solhint-disable no-empty-blocks */
                try IMintableBurnableToken(underlying).transfer(FALLBACK_BURN_ADDRESS, amount) {
                    // if burn is a privileged function on token,
                    // artifically burn by sending to a specified burn address
                } catch {
                    revert("Burn failed");
                }
            }
        }

        // return
        return amount;
    }

    // transferring off of bridge (called on dest chain)
    // to support anySwapInUnderlying / anySwapInAuto
    function withdrawVault(
        address from,
        uint256 amount,
        address to
    ) external virtual returns (uint256) {
        require(hasRole(ROUTER_ROLE, _msgSender()), "Must have router role");

        // consume flow quota (rate limit)
        consumeQuotaOfUser(to, FlowDirection.IN, amount);

        // if locking mode, we burn here and transfer underlying
        if (lockElseMintBurn) {
            // burn adapter token
            _burn(from, amount);
            // transfer underlying to user
            ERC20(underlying).safeTransfer(to, amount);
        }

        // return
        return amount;
    }

    // to support _anySwapIn (transferring off of bridge) (dest chain)
    function mint(address to, uint256 amount) external virtual returns (bool) {
        require(hasRole(ROUTER_ROLE, _msgSender()), "Must have router role");

        // if mint/burn, we customize the standard mint function to instead mint underlying
        if (!lockElseMintBurn) {
            // mints underlying
            if (underlyingBridgeOut != address(0)) {
                IMintableBurnableToken(underlyingBridgeOut).mint(to, amount);
            } else {
                IMintableBurnableToken(underlying).mint(to, amount);
            }
        } else {
            // mint adapter token
            _mint(to, amount);
        }

        // returns bool for consistency with anyswap spec
        return true;
    }

    // to support _anySwapOut / _anySwapIn
    function burn(address from, uint256 amount) external returns (bool) {
        require(hasRole(ROUTER_ROLE, _msgSender()), "Must have router role");
        require(from != address(0), "Cannot burn from 0x0");
        // burn adapter token
        _burn(from, amount);
        // returns bool for consistency with anyswap spec
        return true;
    }

    //// fns for liquidity management

    function deposit(uint256 amount) external returns (uint256) {
        // transfer in underlying
        ERC20(underlying).safeTransferFrom(msg.sender, address(this), amount);

        // mint adapter token
        _mint(msg.sender, amount);

        // if burn, also include a burn of underlying token
        if (!lockElseMintBurn) {
            // burn underlying
            /* solhint-disable-next-line no-empty-blocks */
            try IMintableBurnableToken(underlying).burn(amount) {
                // burned via token's `burn` function
            } catch {
                /* solhint-disable no-empty-blocks */
                try IMintableBurnableToken(underlying).transfer(FALLBACK_BURN_ADDRESS, amount) {
                    // if burn is a privileged function on token,
                    // artifically burn by sending to a specified burn address
                } catch {
                    revert("Burn failed");
                }
            }
        }

        // return
        return amount;
    }

    function withdraw(uint256 amount) external returns (uint256) {
        // burn adapter token
        _burn(msg.sender, amount);

        // if locking mode, we burn here and transfer underlying
        if (lockElseMintBurn) {
            // transfer underlying to user
            ERC20(underlying).safeTransfer(msg.sender, amount);
        } else {
            // mints underlying
            if (underlyingBridgeOut != address(0)) {
                IMintableBurnableToken(underlyingBridgeOut).mint(msg.sender, amount);
            } else {
                IMintableBurnableToken(underlying).mint(msg.sender, amount);
            }
        }

        // return
        return amount;
    }

    //// EIP2771 meta transactions

    function _msgSender() internal view override(Context, ERC2771ContextUpdateable) returns (address) {
        return ERC2771ContextUpdateable._msgSender();
    }

    function _msgData() internal view override(Context, ERC2771ContextUpdateable) returns (bytes calldata) {
        return ERC2771ContextUpdateable._msgData();
    }

    // retrieve tokens erroneously sent in to this address
    function emergencyTokenRetrieve(address token) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Must have admin role");
        // cannot be underlying tokens
        require(token != underlying, "Cannot retrieve underlying");
        // get balance of token
        uint256 tokenBalance = ERC20(token).balanceOf(address(this));
        // transfer all
        ERC20(token).safeTransfer(_msgSender(), tokenBalance);
        // emit
        emit EmergencyTokenRetrieve(_msgSender(), tokenBalance);
    }
}
