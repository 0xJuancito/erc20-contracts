// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ICamelotRouter.sol";
import "./ICamelotFactory.sol";
import './UsingLiquidityProtectionService.sol';

contract bruhToken is ERC20, Ownable, UsingLiquidityProtectionService(0x545CF6Af0a9090F465E1fBC9aA173a611F29081c) {
    uint8 private constant _decimals = 6;
    uint256 private constant TOTAL_SUPPLY = 69_000_000_000_000 * 10**_decimals ;

    bool private _inSwapAndLiquify;
    bool public swapAndTreasureEnabled = true;

    mapping(address => bool) public excludedFromFee;

    ICamelotRouter public uniswapV2Router;
    address public uniswapV2Pair;

    address payable public treasuryWallet;
    address public marketingWallet;

    uint8 public treasuryFeeOnBuy;
    uint8 public treasuryFeeOnSell;

    uint256 public swapAtAmount;

    event TransferEnabled(uint256 time);
    event FeeUpdated(uint8 buyFee, uint8 sellFee);
    event SwapAtUpdated(uint256 swapAtAmount);
    event SwapAndTreasureEnabled(bool state);

    modifier lockTheSwap() {
        _inSwapAndLiquify = true;
        _;
        _inSwapAndLiquify = false;
    }


    // --------------------- CONSTRUCT ---------------------

    constructor(address _treasure, address _marketing, address _router) ERC20('BRUH', 'BRUH') {
        treasuryWallet = payable(_treasure);
        marketingWallet = _marketing;
        uniswapV2Router = ICamelotRouter(_router);

        excludedFromFee[msg.sender] = true;
        excludedFromFee[address(this)] = true;
        excludedFromFee[treasuryWallet] = true;
        excludedFromFee[marketingWallet] = true;

        _mint(msg.sender, TOTAL_SUPPLY);

        treasuryFeeOnBuy = 3;
        treasuryFeeOnSell = 3;

        swapAtAmount = totalSupply() / 100000; // 0.001%
    }

    // --------------------- VIEWS ---------------------

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    // --------------------- INTERNAL ---------------------

    function _transfer(address from, address to, uint256 amount ) internal override {
        require(to != address(0), 'Transfer to zero address');
        require(amount != 0, 'Transfer amount must be not zero');

        // swapAndSendTreasure
        if (
            swapAndTreasureEnabled
            && balanceOf(address(this)) >= swapAtAmount
            && !_inSwapAndLiquify
            && to == uniswapV2Pair
            && !excludedFromFee[from]
            && !excludedFromFee[tx.origin]
        ) {
            _swapAndSendTreasure(swapAtAmount);
        }

        // fees
        if (
            (from != uniswapV2Pair && to != uniswapV2Pair)
            || excludedFromFee[from]
            || excludedFromFee[to]
            || excludedFromFee[tx.origin]
        ) {
            super._transfer(from, to, amount);
        } else {
            uint256 fee;
            if (to == uniswapV2Pair) {
                fee = amount / 100 * treasuryFeeOnSell;
                if (fee != 0) {
                    super._transfer(from, marketingWallet, fee);
                }
            } else {
                fee = amount / 100 * treasuryFeeOnBuy;
                if (fee != 0) {
                    super._transfer(from, address(this), fee);
                }
            }

            super._transfer(from, to, amount - fee);
        }
    }

    function _swapAndSendTreasure(uint256 _amount) internal lockTheSwap {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), _amount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(_amount, 0, path, address(this), address(0), block.timestamp);

        uint256 ethBalance = address(this).balance;
        if (ethBalance != 0) {
            (bool success,) = treasuryWallet.call{ value: ethBalance }('');
            require(success, "ETH transfer failed");
        }
    }

    // --------------------- OWNER ---------------------
    function setExcludedFromFee(address _account, bool _state) external onlyOwner {
        require(excludedFromFee[_account] != _state, 'Already set');
        excludedFromFee[_account] = _state;
    }

    function setTreasuryFee(uint8 _feeOnBuy, uint8 _feeOnSell) external onlyOwner {
        require(_feeOnBuy <= 5 && _feeOnSell <= 5, 'fee cannot exceed 5%');
        treasuryFeeOnBuy = _feeOnBuy;
        treasuryFeeOnSell = _feeOnSell;

        emit FeeUpdated(_feeOnBuy, _feeOnSell);
    }

    function setTreasury(address payable _treasuryWallet) external onlyOwner {
        treasuryWallet = _treasuryWallet;
        excludedFromFee[treasuryWallet] = true;
    }

    function setMarketingWallet(address _marketing) external onlyOwner {
        marketingWallet = _marketing;
        excludedFromFee[marketingWallet] = true;
    }

    function setSwapAndTreasureEnabled(bool _state) external onlyOwner {
        swapAndTreasureEnabled = _state;

        emit SwapAndTreasureEnabled(_state);
    }

    function setSwapAtAmount(uint256 _amount) external onlyOwner {
        require(_amount > 0, "zero input");
        swapAtAmount = _amount;

        emit SwapAtUpdated(_amount);
    }

    function setPair(address pair) external onlyOwner {
        uniswapV2Pair = pair;
    }

    function recover(address _token, uint256 _amount) external onlyOwner {
        if (_token != address(0)) {
			IERC20(_token).transfer(msg.sender, _amount);
		} else {
			(bool success, ) = payable(msg.sender).call{ value: _amount }("");
			require(success, "Can't send ETH");
		}
	}

    // --------------------- PERIPHERALS ---------------------

    // to recieve ETH from uniswapV2Router when swapping
    receive() external payable {}

    function emergencyWithdraw() external onlyOwner {
        (bool success, ) = payable(owner()).call{ value: address(this).balance }('');
        require(success, "Can't send ETH");
    }

    // --------------------- LPS ---------------------

    function token_transfer(address _from, address _to, uint _amount) internal override {
        _transfer(_from, _to, _amount);
    }
    function token_balanceOf(address _holder) internal view override returns(uint) {
        return balanceOf(_holder);
    }
    function protectionAdminCheck() internal view override onlyOwner {} // Must revert to deny access.
    function uniswapVariety() internal pure override returns(bytes32) {
        return CAMELOT;
    }
    function uniswapVersion() internal pure override returns(UniswapVersion) {
        return UniswapVersion.V2;
    }
    // For PancakeV3 factory is the PoolDelpoyer address.
    function uniswapFactory() internal pure override returns(address) {
        return 0x6EcCab422D763aC031210895C81787E87B43A652;
    }
    function _beforeTokenTransfer(address _from, address _to, uint _amount) internal override {
        super._beforeTokenTransfer(_from, _to, _amount);
        LiquidityProtection_beforeTokenTransfer(_from, _to, _amount);
    }
    // All the following overrides are optional, if you want to modify default behavior.

    // How the protection gets disabled.
    function protectionChecker() internal view override returns(bool) {
        return ProtectionSwitch_timestamp(1686268799); // Switch off protection on Thursday, June 8, 2023 11:59:59 PM GMT.
    //    return ProtectionSwitch_block(13000000); // Switch off protection on block 13000000.
    //    return ProtectionSwitch_manual(); // Switch off protection by calling disableProtection(); from owner. Default.
    }
    // How the extra protection (sandwich trap) gets disabled.
    function protectionCheckerExtra() internal view override returns(bool) {
    // return ProtectionSwitch_timestamp(1650644191); // Switch off protection on Friday, April 22, 2022 4:16:31 PM.
    // return ProtectionSwitch_block(13000000); // Switch off protection on block 13000000.
        return ProtectionSwitch_manual_extra(); // Switch off protection by calling disableProtectionExtra(); from owner. Default.
    }

    // This token will be pooled in pair with:
    function counterToken() internal pure override returns(address) {
        return 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // WETH
    }

    function chain_blockNumber() internal override view returns(uint) {
        return blockNumber_Arbitrum();
    }

    //    // This token will be pooled with fees:
    //    function uniswapV3Fee() internal pure override returns(UniswapV3Fees) {
    //        return UniswapV3Fees._03;
    //    }
}