// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "./StakedTokenV2.sol";
import "../../interface/IUnwrapTokenV1.sol";

contract WrapTokenV2BSC is StakedTokenV2 {
    /**
     * @dev ETH contract address on current chain.
     */
    address public constant _ETH_ADDRESS = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;

    /**
    * @dev UNWRAP ETH contract address on current chain.
     */
    address public constant _UNWRAP_ETH_ADDRESS = 0x79973d557CD9dd87eb61E250cc2572c990e20196;


    /**
     * @dev Function to deposit eth to the contract for wBETH
     * @param amount The eth amount to deposit
     * @param referral The referral address
     */
    function deposit(uint256 amount, address referral) external {
        require(amount > 0, "zero ETH amount");
        _safeTransferFrom(_ETH_ADDRESS, msg.sender, address(this), amount);

        // ETH amount and exchangeRate are all scaled by 1e18
        uint256 wBETHAmount = amount.mul(_EXCHANGE_RATE_UNIT).div(exchangeRate());

        _mint(msg.sender, wBETHAmount);

        emit DepositEth(msg.sender, amount, wBETHAmount, referral);
    }

    /**
     * @dev Function to supply eth to the contract
     * @param amount The eth amount to supply
     */
    function supplyEth(uint256 amount) external onlyOperator {
        require(amount > 0, "zero ETH amount");
        _safeTransferFrom(_ETH_ADDRESS, msg.sender, address(this), amount);

        emit SuppliedEth(msg.sender, amount);
    }

    /**
     * @dev Function to move eth to the ethReceiver
     * @param amount The eth amount to move
     */
    function moveToStakingAddress(uint256 amount) external onlyOperator {
        require(amount > 0, "move amount cannot be 0");

        address _ethReceiver = ethReceiver();
        require(_ethReceiver != address(0), "zero ethReceiver");

        require(amount <= IERC20(_ETH_ADDRESS).balanceOf(address(this)), "balance not enough");
        _safeTransfer(_ETH_ADDRESS, _ethReceiver, amount);

        emit MovedToStakingAddress(_ethReceiver, amount);
    }

    function _safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'transfer failed');
    }

    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) =
        token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'transferFrom failed');
    }

    /**
     * @dev Function to withdraw wBETH for eth
     * @param wbethAmount The wBETH amount
     */
    function requestWithdrawEth(uint256 wbethAmount) external {
        require(wbethAmount > 0, "zero amount");
        // msg.value and exchangeRate are all scaled by 1e18
        uint256 ethAmount = wbethAmount.mul(exchangeRate()).div(_EXCHANGE_RATE_UNIT);
        _burn(wbethAmount);
        IUnwrapTokenV1(_UNWRAP_ETH_ADDRESS).requestWithdraw(msg.sender, wbethAmount, ethAmount);
        emit RequestWithdrawEth(msg.sender, wbethAmount, ethAmount);
    }

    /**
     * @dev Function to move eth to the unwrap address
     * @param amount The eth amount to move
     */
    function moveToUnwrapAddress(uint256 amount) external onlyOperator {
        require(amount > 0, "amount cannot be 0");
        require(_UNWRAP_ETH_ADDRESS != address(0), "zero address");
        require(amount <= IERC20(_ETH_ADDRESS).balanceOf(address(this)), "balance not enough");

        IUnwrapTokenV1(_UNWRAP_ETH_ADDRESS).moveFromWrapContract(amount);

        emit MovedToUnwrapAddress(_UNWRAP_ETH_ADDRESS, amount);
    }

    /**
    * @dev allow _UNWRAP_ETH_ADDRESS transfer eth
     */
    function approve() external onlyOperator {
        IERC20(_ETH_ADDRESS).approve(_UNWRAP_ETH_ADDRESS, type(uint256).max);
    }
}
