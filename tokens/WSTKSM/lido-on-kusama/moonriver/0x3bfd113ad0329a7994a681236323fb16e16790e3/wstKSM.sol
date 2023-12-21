// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ERC20.sol";
import "IERC20.sol";
import "ILido.sol";

contract WstKSM is ERC20 {
    // LIDO contract
    ILido public LIDO;

    // vKSM precompile
    IERC20 public VKSM;

    /**
     * @param _lido address of the StKSM token to wrap
     */
    constructor(ILido _lido, IERC20 _vKSM) ERC20("Wrapped liquid staked KSM", "wstKSM") {
        LIDO = _lido;
        VKSM = _vKSM;
    }

    /**
    * @notice Stub fallback for native token, always reverting
    */
    fallback() external {
        revert("WSTKSM: FORBIDDEN");
    }

    /**
     * @return the number of decimals for getting user representation of a token amount.
     */
    function decimals() public view override returns (uint8) {
        return 12;
    }

    /**
     * @notice Stake vKSM to stKSM and wrap stKSM to wstKSM
     * @param _vKSMAmount amount of vKSM
     * @return Amount of wstKSM for a given vKSM amount
     */
    function submit(uint256 _vKSMAmount) external returns (uint256) {
        require(_vKSMAmount > 0, "WSTKSM: ZERO_VKSM");
        VKSM.transferFrom(msg.sender, address(this), _vKSMAmount);
        if (VKSM.allowance(address(this), address(LIDO)) < _vKSMAmount) {
            VKSM.approve(address(LIDO), type(uint256).max);
        }
        uint256 shares = LIDO.deposit(_vKSMAmount);
        require(shares > 0, "WSTKSM: ZERO_SHARES");
        _mint(msg.sender, shares);
        return shares;
    }

    /**
     * @notice Wrap stKSM to wstKSM
     * @param _stKSMAmount amount of stKSM
     * @return Amount of wstKSM for a given stKSM amount
     */
    function wrap(uint256 _stKSMAmount) external returns (uint256) {
        require(_stKSMAmount > 0, "WSTKSM: ZERO_STKSM");
        uint256 wstKSMAmount = LIDO.getSharesByPooledKSM(_stKSMAmount);
        require(wstKSMAmount > 0, "WSTKSM: MINT_ZERO_AMOUNT");
        _mint(msg.sender, wstKSMAmount);
        require(LIDO.transferFrom(msg.sender, address(this), _stKSMAmount), "WSTKSM: TRANSFER_FROM_REVERT");
        return wstKSMAmount;
    }

    /**
     * @notice Unwrap wstKSM to stKSM
     * @param _wstKSMAmount amount of wstKSM
     * @return Amount of stKSM for a given wstKSM amount
     */
    function unwrap(uint256 _wstKSMAmount) external returns (uint256) {
        require(_wstKSMAmount > 0, "WSTKSM: ZERO_WSTKSM");
        uint256 stKSMAmount = LIDO.getPooledKSMByShares(_wstKSMAmount);
        require(stKSMAmount > 0, "WSTKSM: BURN_ZERO_AMOUNT");
        _burn(msg.sender, _wstKSMAmount);
        require(LIDO.transfer(msg.sender, stKSMAmount), "WSTKSM: TRANSFER_REVERT");
        return stKSMAmount;
    }

    /**
     * @notice Get amount of wstKSM for a given amount of stKSM
     * @param _stKSMAmount amount of stKSM
     * @return Amount of wstKSM for a given stKSM amount
     */
    function getWstKSMByStKSM(uint256 _stKSMAmount) external view returns (uint256) {
        return LIDO.getSharesByPooledKSM(_stKSMAmount);
    }

    /**
     * @notice Get amount of stKSM for a given amount of wstKSM
     * @param _wstKSMAmount amount of wstKSM
     * @return Amount of stKSM for a given wstKSM amount
     */
    function getStKSMByWstKSM(uint256 _wstKSMAmount) external view returns (uint256) {
        return LIDO.getPooledKSMByShares(_wstKSMAmount);
    }
}