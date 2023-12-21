// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;
import "./Uniswap.sol";
import "./ERC20.sol";
import "./SafeMath.sol";
import "./Ownable.sol";
import "./ManagerInterface.sol";
import "./ReentrancyGuard.sol";

contract Token is Ownable, ERC20,ReentrancyGuard {
    using SafeMath for uint256;
    ManagerInterface public manager;

    uint256 public amountPlayToEarn = 400 * 10**6 * 10**18;
    uint256 public playToEarnReward;
    uint256 internal amountFarm = 50 * 10**6 * 10**18;
    uint256 private farmReward;
    address public addressForMarketing;
    uint256 public sellFeeRate = 5;
    uint256 public buyFeeRate = 2;
    IUniswapV2Router02 public uniswapV2Router;
    IUniswapV2Router02 public apeswapV2Router;
    address public uniswapV2Pair;
    address public apeswapV2Pair;
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        addressForMarketing = _msgSender();
        uniswapV2Router = IUniswapV2Router02(
            0x10ED43C718714eb63d5aA57B78B54704E256024E
        );
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory())
        .createPair(address(this), uniswapV2Router.WETH());
        _approve(address(this), address(uniswapV2Router), ~uint256(0));
        
        apeswapV2Router = IUniswapV2Router02(
            0xcF0feBd3f17CEf5b47b0cD257aCf6025c5BFf3b7
        );
        apeswapV2Pair = IUniswapV2Factory(apeswapV2Router.factory())
        .createPair(address(this), apeswapV2Router.WETH());
        _approve(address(this), address(apeswapV2Router), ~uint256(0));
        
    }
   

    modifier onlyOperator() {
        require(manager.isOperator(_msgSender()), "you're not operator");
        _;
    }
 
    function setManager(address _manager) public onlyOwner {
        manager = ManagerInterface(_manager);
    }
    function farm(address recipient, uint256 amount) external onlyOperator {
        require(amountFarm > farmReward, "Over cap farm");
        require(recipient != address(0), "invalid address");
        require(amount > 0, "amount > 0");

        
        if (farmReward.add(amount) <= amountFarm){
            farmReward = farmReward.add(amount);
           _mint(recipient, amount);   
        }
        else {
            uint256 availableReward = amountFarm.sub(farmReward);
            _mint(recipient, availableReward);
            farmReward = amountFarm;
        }
    }

    function win(address winner, uint256 reward) external onlyOperator {
        require(playToEarnReward < amountPlayToEarn, "Over cap earn");
        require(winner != address(0), "invalid address");
        require(reward > 0, "reward > 0");
        if (playToEarnReward.add(reward) <= amountPlayToEarn){
            playToEarnReward = playToEarnReward.add(reward);
            _mint(winner, reward);   
          
        }
        else {
            uint256 availableReward = amountPlayToEarn.sub(playToEarnReward);
            _mint(winner, availableReward);
            playToEarnReward = amountPlayToEarn;
        }
    }
    function swapTokenForMarketing() public nonReentrant {
        uint256 contractTokenBalance = balanceOf(address(this));
        swapTokensForEth(contractTokenBalance);
        
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = apeswapV2Router.WETH();
        apeswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            addressForMarketing,
            block.timestamp
        );
    }

    function setAddressForMarketing(address _addressForMarketing) external onlyOwner {
        require(_addressForMarketing != address(0), "invalid address");
        addressForMarketing = _addressForMarketing;
    }
}