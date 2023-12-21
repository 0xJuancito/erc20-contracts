// SPDX-License-Identifier: ISC

// Solidity files have to start with this pragma.
// It will be used by the Solidity compiler to validate its version.
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


contract LiquidityTimelock is Ownable{
    using SafeERC20 for IERC20;

    // ERC20 basic token contract being held
    IERC20 private immutable _token;

    // beneficiary of tokens after they are released
    address private immutable _beneficiary;
    
    // Incremental period in seconds
    uint256 private immutable _period;

    // timestamp when token release is enabled
    uint256 private _releaseTime;


    constructor(
        IERC20 token_,
        address beneficiary_,
        uint256 period_
    ) {
        _token = token_;
        _beneficiary = beneficiary_;
        _period = period_;
        _releaseTime = block.timestamp + period_;
    }

    /**
     * @return the token being held.
     */
    function token() public view  returns (IERC20) {
        return _token;
    }

    /**
     * @return the beneficiary of the tokens.
     */
    function beneficiary() public view  returns (address) {
        return _beneficiary;
    }

    /**
     * @return the time when the tokens are released.
     */
    function releaseTime() public view  returns (uint256) {
        return _releaseTime;
    }

     /**
     * @return the time when the tokens are released.
     */
    function period() public view  returns (uint256) {
        return _period;
    }

    /**
     * @notice Transfers tokens held by timelock to beneficiary.
     */
    function release() public  {
        require(block.timestamp >= releaseTime(), "TokenTimelock: current time is before release time");

        uint256 amount = token().balanceOf(address(this));
        require(amount > 0, "TokenTimelock: no tokens to release");

        token().safeTransfer(beneficiary(), amount);
    }

    /**
     * @notice Transfers tokens held by timelock to beneficiary.
     */
    function renew() public onlyOwner {
        _releaseTime = block.timestamp + period();
    }
}