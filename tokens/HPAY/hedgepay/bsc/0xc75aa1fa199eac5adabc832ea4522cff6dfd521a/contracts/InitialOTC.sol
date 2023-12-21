// SPDX-License-Identifier: ISC

// Solidity files have to start with this pragma.
// It will be used by the Solidity compiler to validate its version.
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

import "../interfaces/IFundManager.sol";
import "./lib/SwapUtils.sol";
import "./lib/PresaleUtils.sol";
import "./LiquidityTimeLock.sol";

contract InitialOTC is AccessControl {
    event TokensPurchased(
        address purchaser,
        address beneficiary,
        uint256 value,
        uint256 amount
    );

    event TokensSold(
        address seller,
        address beneficiary,
        uint256 value,
        uint256 amount
    );

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    uint64 public constant LAUNCH_PRICE = 60 * 1e14;

    uint256 public swapSlippage = 50; // 0.5%
    uint256 public currentPhase;
    uint256 public rawCapitalRaised;

    address public liquidityLock;
    // Reference to the BUSD contract
    ERC20 public busd;
    ERC20PresetMinterPauser public token;

    // We use the router to swap our tokens as needed
    IUniswapV2Router02 public router;
    IFund public fund;

    PresaleUtils.PresalePhase[4] public phases;
    mapping(address => uint256) public balance;

    constructor( address _token) {
        require(_token != address(0), "ICO: token is the zero address");
        token = ERC20PresetMinterPauser(_token);

        busd = ERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
        router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, msg.sender);
        // TODO: Change this to expected values
       configurePhase(0, 
            48 * 1e14, // 0.0048 $
            4568 * 1e12, // 0.00456 $
            500 * 1e18, // 50$
            3000 * 1e18, // 3000$
            300_000 * 1e18 // 300,000$
        );

        configurePhase(1, 
            51 * 1e14, // 0.0051 $
            4568 * 1e12, // 0.00456 $
            50 * 1e18, // 50$
            6000 * 1e18, // 3000$
            618_750 * 1e18 // 318,750$
        );

        configurePhase(2, 
            54 * 1e14, 
            4568 * 1e12, 
            50 * 1e18, 
            8000 * 1e18, 
            956_250 * 1e18 
        );
        
        configurePhase(3, 
            57 * 1e14, 
            4568 * 1e12,
            50 * 1e18,
            10000 * 1e18, 
            1_312_500 * 1e18 
        );
    }

    function configurePhase(
        uint256 _pid,
        uint256 _rate,
        uint256 _sellRate,
        uint256 _minPurchase,
        uint256 _maxPurchase,
        uint256 _hardCap
    ) public onlyRole(MANAGER_ROLE){
        PresaleUtils.PresalePhase storage phase = phases[_pid];
        phase.rate = _rate;
        phase.sellRate = _sellRate;
        phase.minPurchase = _minPurchase;
        phase.maxPurchase = _maxPurchase;
        phase.hardCap = _hardCap;
    }

    function endCurrentPhase() external onlyRole(MANAGER_ROLE) {
        require(phases[currentPhase].status == 1, "Invalid status");
        phases[currentPhase].status = 2;

        if(currentPhase < phases.length - 1) {
            currentPhase++;
        }
    }

    function startNextPhase() external onlyRole(MANAGER_ROLE) {
        require(currentPhase < phases.length, "Invalid phase");
        if(currentPhase > 0) {
            require(phases[currentPhase - 1].status == 2, "Invalid status");
        }
        phases[currentPhase].status = 1;
    }

    receive() external payable {
        buyWithChainCoin(_msgSender());
    }

    function buy(uint256 amount) external {
        address beneficiary = msg.sender;
        uint256 tokens = _getTokenAmount(amount);
        _preValidatePurchase(beneficiary, amount, tokens);
        busd.transferFrom(address(msg.sender), address(this), amount);
        _processPurchase(beneficiary, amount, tokens);
        emit TokensPurchased(_msgSender(), beneficiary, amount, tokens);
    }

    function buyWithChainCoin(address beneficiary) public payable {
        uint256 weiAmount = msg.value;

        // Buy busd with 0.5% slippage
        uint256 amount = SwapUtils.swapExactETHForTokens(router, busd, weiAmount, swapSlippage); // no checks required for this? 
        
        uint256 tokens = _getTokenAmount(amount);
        _preValidatePurchase(beneficiary, amount, tokens);
        _processPurchase(beneficiary, amount, tokens);
        emit TokensPurchased(_msgSender(), beneficiary, amount, tokens);
    }

    function sellTokens(uint256 amount) external {
        address beneficiary = address(msg.sender);
        require(beneficiary != address(0),"Sale: beneficiary is the zero address");
        require(amount > 0, "Sale: tokenAmount is 0");
        require(balance[msg.sender] >= amount, "Balance to low");

        _drainTokens(_msgSender(), amount);
        balance[msg.sender] -= amount;

        uint256 netAmount = _getRefundAmount(amount);
        rawCapitalRaised -= netAmount; 
        if(phases[currentPhase]._capital >= netAmount){
            phases[currentPhase]._capital -= netAmount; 
        }
        _processSell(beneficiary, netAmount);
        emit TokensSold(_msgSender(), beneficiary, netAmount, amount);
    }

    function _preValidatePurchase(address beneficiary, uint256 amount, uint256 tokens) internal view {
        PresaleUtils.PresalePhase memory phase= phases[currentPhase]; 
        PresaleUtils.preValidatePurchase(phase, beneficiary, amount);
        require(rawCapitalRaised + amount <= phase.hardCap, "Buy: Hardcap reached");
        require(balance[beneficiary] + tokens >= _getTokenAmount(phase.minPurchase), "Must buy min mount");
        require(balance[beneficiary] + tokens <= _getTokenAmount(phase.maxPurchase), "Address cap reached");
        require(address(fund) != address(0), "Fund not set");
    }

    function _deliverTokens(address beneficiary, uint256 tokenAmount) internal {
        token.transfer(beneficiary, tokenAmount);
    }

    function _drainTokens(address seller, uint256 tokenAmount) internal {
        token.transferFrom(seller, address(this), tokenAmount);
    }

    function _processPurchase(address beneficiary, uint256 usdAmount, uint256 tokenAmount) internal {
        balance[msg.sender] += tokenAmount;
        phases[currentPhase]._capital += usdAmount;
        rawCapitalRaised += usdAmount;
        uint256 fee = usdAmount - _getRefundAmount(tokenAmount); 
        busd.increaseAllowance(address(fund), fee);
        fund.investBUSD(fee);
        _deliverTokens(beneficiary, tokenAmount);
    }

    function _processSell(address beneficiary, uint256 weiAmount) internal {
        busd.transfer(beneficiary, weiAmount);
    }

    function _getTokenAmount(uint256 amount) internal view returns (uint256) {
        return (amount / rate()) * 10 ** token.decimals();
    }

    function _getRefundAmount(uint256 tokenAmount) internal view returns (uint256) {
        return (tokenAmount * sellRate()) / 10 ** token.decimals();
    }

    function setFund(address _address) external onlyRole(MANAGER_ROLE) {
        require(_address != address(0), "Fund address cannot be 0x00");
        fund = IFund(_address);
    }

    function capital() public view returns (uint256) {
        return busd.balanceOf(address(this));
    }

    function saleSupply() public view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function rate() public view returns(uint256) {
        return phases[currentPhase].rate;
    }

    function sellRate() public view returns(uint256) {
        return phases[currentPhase].sellRate;
    }

    function setSwapSlippage(uint256 slipapge) external onlyRole(MANAGER_ROLE) {
        require(slipapge <= 10_000, "Slippage cannot be > 100%"); 
        swapSlippage = slipapge;
    }

     function endPresaleAndLock(address lockOwner) external onlyRole(MANAGER_ROLE)  {
        require(currentPhase == phases.length - 1, "Cannot end");
        uint256 busdBalance = busd.balanceOf(address(this));
        uint256 liquidity = (busdBalance * 95) / 100;
        uint256 tokenLiquidityAmount = liquidity / LAUNCH_PRICE;

        token.mint(address(this), tokenLiquidityAmount);
        token.increaseAllowance(address(router), tokenLiquidityAmount);
        busd.increaseAllowance(address(router), liquidity);


        liquidityLock = PresaleUtils.lockLiquidity(
                router,
                token,
                busd,
                tokenLiquidityAmount,
                liquidity,
                lockOwner
        );
        busd.transfer(lockOwner, busd.balanceOf(address(this)));
        token.burn(token.balanceOf(address(this)));
    }


    /// Can only be destroyed by multisign
    function destroy() external onlyRole(DEFAULT_ADMIN_ROLE) {
        busd.transfer(msg.sender, busd.balanceOf(address(this)));
        token.transfer(msg.sender, token.balanceOf(address(this))); 
        selfdestruct(payable(msg.sender));
    }
}
