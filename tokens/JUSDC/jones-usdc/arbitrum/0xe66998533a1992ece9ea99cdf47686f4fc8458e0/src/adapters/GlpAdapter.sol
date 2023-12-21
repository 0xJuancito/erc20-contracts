//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20, IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {IGmxRewardRouter} from "../interfaces/IGmxRewardRouter.sol";
import {IGlpManager, IGMXVault} from "../interfaces/IGlpManager.sol";
import {IJonesGlpVaultRouter} from "../interfaces/IJonesGlpVaultRouter.sol";
import {Operable, Governable} from "../common/Operable.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {MerkleProof} from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import {WhitelistController} from "src/common/WhitelistController.sol";
import {IAggregatorV3} from "src/interfaces/IAggregatorV3.sol";
import {JonesGlpLeverageStrategy} from "src/glp/strategies/JonesGlpLeverageStrategy.sol";
import {JonesGlpStableVault} from "src/glp/vaults/JonesGlpStableVault.sol";

contract GlpAdapter is Operable, ReentrancyGuard {
    IJonesGlpVaultRouter public vaultRouter;
    IGmxRewardRouter public gmxRouter = IGmxRewardRouter(0xB95DB5B167D75e6d04227CfFFA61069348d271F5);
    IAggregatorV3 public oracle = IAggregatorV3(0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3);
    IERC20 public glp = IERC20(0x5402B5F40310bDED796c7D0F3FF6683f5C0cFfdf);
    IERC20 public usdc = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    WhitelistController public controller;
    JonesGlpLeverageStrategy public strategy;
    JonesGlpStableVault public stableVault;

    bytes32 private root;
    uint256 public flexibleTotalCap;
    bool public hatlistStatus;
    bool public useFlexibleCap;

    mapping(address => bool) public isValid;

    uint256 public constant BASIS_POINTS = 1e12;

    constructor(address[] memory _tokens, address _controller, address _strategy, address _stableVault)
        Governable(msg.sender)
    {
        uint8 i = 0;
        for (; i < _tokens.length;) {
            _editToken(_tokens[i], true);
            unchecked {
                i++;
            }
        }

        controller = WhitelistController(_controller);
        strategy = JonesGlpLeverageStrategy(_strategy);
        stableVault = JonesGlpStableVault(_stableVault);
    }

    function zapToGlp(address _token, uint256 _amount, bool _compound, bytes32[] memory _proof)
        external
        nonReentrant
        validToken(_token)
        returns (uint256)
    {
        _validateSender(_proof);

        IERC20(_token).transferFrom(msg.sender, address(this), _amount);

        IERC20(_token).approve(gmxRouter.glpManager(), _amount);
        uint256 mintedGlp = gmxRouter.mintAndStakeGlp(_token, _amount, 0, 0);

        glp.approve(address(vaultRouter), mintedGlp);
        uint256 receipts = vaultRouter.depositGlp(mintedGlp, msg.sender, _compound);

        return receipts;
    }

    function zapToGlpEth(bool _compound, bytes32[] memory _proof) external payable nonReentrant returns (uint256) {
        _validateSender(_proof);

        uint256 mintedGlp = gmxRouter.mintAndStakeGlpETH{value: msg.value}(0, 0);

        glp.approve(address(vaultRouter), mintedGlp);

        uint256 receipts = vaultRouter.depositGlp(mintedGlp, msg.sender, _compound);

        return receipts;
    }

    function redeemGlpBasket(uint256 _shares, bool _compound, address _token, bool _native)
        external
        nonReentrant
        validToken(_token)
        returns (uint256)
    {
        _onlyEOA();

        uint256 assetsReceived = vaultRouter.redeemGlpAdapter(_shares, _compound, _token, msg.sender, _native);

        return assetsReceived;
    }

    function depositGlp(uint256 _assets, bool _compound, bytes32[] memory _proof)
        external
        nonReentrant
        returns (uint256)
    {
        _validateSender(_proof);

        glp.transferFrom(msg.sender, address(this), _assets);

        glp.approve(address(vaultRouter), _assets);

        uint256 receipts = vaultRouter.depositGlp(_assets, msg.sender, _compound);

        return receipts;
    }

    function depositStable(uint256 _assets, bool _compound, bytes32[] memory _proof)
        external
        nonReentrant
        returns (uint256)
    {
        _validateSender(_proof);

        if (useFlexibleCap) {
            _checkUsdcCap(_assets);
        }

        usdc.transferFrom(msg.sender, address(this), _assets);

        usdc.approve(address(vaultRouter), _assets);

        uint256 receipts = vaultRouter.depositStable(_assets, _compound, msg.sender);

        return receipts;
    }

    function updateGmxRouter(address _gmxRouter) external onlyGovernor {
        gmxRouter = IGmxRewardRouter(_gmxRouter);
    }

    function updateVaultRouter(address _vaultRouter) external onlyGovernor {
        vaultRouter = IJonesGlpVaultRouter(_vaultRouter);
    }

    function _editToken(address _token, bool _valid) internal {
        isValid[_token] = _valid;
    }

    function updateRoot(bytes32 _root) external onlyGovernor {
        root = _root;
    }

    function toggleHatlist(bool _status) external onlyGovernor {
        hatlistStatus = _status;
    }

    function toggleFlexibleCap(bool _status) external onlyGovernor {
        useFlexibleCap = _status;
    }

    function updateFlexibleCap(uint256 _newAmount) public onlyGovernor {
        //18 decimals -> $1mi = 1_000_000e18
        flexibleTotalCap = _newAmount;
    }

    function getFlexibleCap() public view returns (uint256) {
        return flexibleTotalCap; //18 decimals
    }

    function usingFlexibleCap() public view returns (bool) {
        return useFlexibleCap;
    }

    function usingHatlist() public view returns (bool) {
        return hatlistStatus;
    }

    function getUsdcCap() public view returns (uint256 usdcCap) {
        usdcCap = (flexibleTotalCap * (strategy.getTargetLeverage() - BASIS_POINTS)) / strategy.getTargetLeverage();
    }

    function belowCap(uint256 _amount) public view returns (bool) {
        uint256 increaseDecimals = 10;
        (, int256 lastPrice,,,) = oracle.latestRoundData(); //8 decimals
        uint256 price = uint256(lastPrice) * (10 ** increaseDecimals); //18 DECIMALS
        uint256 usdcCap = getUsdcCap(); //18 decimals
        uint256 stableTvl = stableVault.tvl(); //18 decimals
        uint256 denominator = 1e6;

        uint256 notional = (price * _amount) / denominator;

        if (stableTvl + notional > usdcCap) {
            return false;
        }

        return true;
    }

    function _onlyEOA() private view {
        if (msg.sender != tx.origin && !controller.isWhitelistedContract(msg.sender)) {
            revert NotWhitelisted();
        }
    }

    function _isHatlisted(bytes32[] memory _proof) private view {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender))));
        bool verified = MerkleProof.verify(_proof, root, leaf);

        if (!verified) {
            revert NotHatlisted();
        }
    }

    function _validateSender(bytes32[] memory _proof) private view {
        if (hatlistStatus) {
            _isHatlisted(_proof);
            _onlyEOA();
        } else {
            _onlyEOA();
        }
    }

    function _checkUsdcCap(uint256 _amount) private view {
        if (!belowCap(_amount)) {
            revert OverUsdcCap();
        }
    }

    function editToken(address _token, bool _valid) external onlyGovernor {
        _editToken(_token, _valid);
    }

    modifier validToken(address _token) {
        require(isValid[_token], "Invalid token.");
        _;
    }

    error NotHatlisted();
    error OverUsdcCap();
    error NotWhitelisted();
}
