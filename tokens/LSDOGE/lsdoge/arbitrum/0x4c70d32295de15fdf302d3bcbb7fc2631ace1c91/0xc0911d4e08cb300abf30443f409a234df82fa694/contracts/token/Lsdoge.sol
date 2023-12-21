// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IStakingYieldPool.sol";
import "../interfaces/ICamelotRouter.sol";

contract Lsdoge is UUPSUpgradeable, ERC20Upgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;
    address private constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address private constant ZERO = 0x0000000000000000000000000000000000000000;

    IERC20 public weth;
    IStakingYieldPool public pool;
    ICamelotRouter public router;
    address public treasury;

    uint256 public burnFee;
    uint256 public rewardFee;
    uint256 public totalFee;
    uint256 public feeDenominator;

    bool public isLaunched;

    mapping(address => bool) public isFeeExemptSender;
    mapping(address => bool) public isFeeExemptRecipient;
    mapping(address => bool) public isPair;

    bool public inSwap;
    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }

    event TakeFee(address indexed user, uint256 burn, uint256 reward, uint256 treasury);

    constructor() initializer {}

    function initialize(IERC20 _weth, ICamelotRouter _router, address _treasury, uint256 _supply) external initializer {
        __ERC20_init("LSDOGE", "LSDOGE");
        __Ownable_init();

        isFeeExemptSender[msg.sender] = true;
        isFeeExemptRecipient[msg.sender] = true;
        weth = _weth;
        router = _router;
        treasury = _treasury;
        _mint(msg.sender, _supply);
    }

    function decimals() public pure virtual override returns (uint8) {
        return 9;
    }

    function updateFee(uint256 _burn, uint256 _reward, uint256 _total, uint256 _denominator) external onlyOwner {
        burnFee = _burn;
        rewardFee = _reward;
        totalFee = _total;
        feeDenominator = _denominator;
    }

    function setRewardPool(IStakingYieldPool _pool) external onlyOwner {
        pool = _pool;
    }

    function setFeeExemptSender(address _sender, bool _status) external onlyOwner {
        isFeeExemptSender[_sender] = _status;
    }

    function setFeeExemptRecipient(address _recipient, bool _status) external onlyOwner {
        isFeeExemptRecipient[_recipient] = _status;
    }

    function setRouter(ICamelotRouter _router) external onlyOwner {
        router = _router;
    }

    function setLaunched(bool _launched) external onlyOwner {
        isLaunched = _launched;
    }

    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        return _internalTransfer(_msgSender(), to, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(sender, spender, amount);
        return _internalTransfer(sender, recipient, amount);
    }

    function _internalTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        if (inSwap) {
            _transfer(sender, recipient, amount);
            return true;
        }
        uint256 amountReceived = (!isFeeExemptSender[sender] && !isFeeExemptRecipient[recipient]) ? takeFee(sender, amount) : amount;
        _transfer(sender, recipient, amountReceived);
        return true;
    }

    function takeFee(address sender, uint256 amount) internal returns (uint256) {
        uint256 feeAmount = (amount * totalFee) / feeDenominator;
        _transfer(sender, address(this), feeAmount);

        if (shouldProcessFee()) {
            processFee();
        }

        return amount - feeAmount;
    }

    function shouldProcessFee() internal view returns (bool) {
        return !inSwap && isLaunched && balanceOf(address(this)) > 0 && !isPair[msg.sender];
    }

    function processFee() internal swapping {
        uint256 fee = balanceOf(address(this));
        uint256 amountBurn = (fee * burnFee) / totalFee;
        uint256 amountReward = (fee * rewardFee) / totalFee;
        uint256 amountTreasury = fee - amountBurn - amountReward;

        if (address(pool) != address(0)) {
            _transfer(address(this), address(pool), amountReward);
            pool.notifyRewardAmount(amountReward);
        }

        _transfer(address(this), DEAD, amountBurn);

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = address(weth);

        _approve(address(this), address(router), amountTreasury);
        try router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amountTreasury, 0, path, treasury, address(0), block.timestamp) {
        } catch {
            _transfer(address(this), treasury, amountTreasury);
        }

        emit TakeFee(msg.sender, amountBurn, amountReward, amountTreasury);
    }

    function getCirculatingSupply() public view returns (uint256) {
        return totalSupply() - balanceOf(DEAD) - balanceOf(ZERO);
    }

    function recoverToken(address[] calldata tokens) external onlyOwner {
        unchecked {
            for (uint8 i; i < tokens.length; i++) {
                IERC20(tokens[i]).safeTransfer(msg.sender, IERC20(tokens[i]).balanceOf(address(this)));
            }
        }
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
