// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.6.11;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin/ERC20UpgradeSafe.sol";
import "../lib/Lockable.sol";
import "../lib/Pausable.sol";
import "../lib/MathUtils.sol";
import "../lib/interfaces/IFeeRecipient.sol";

contract AETH_R21 is OwnableUpgradeSafe, ERC20UpgradeSafe, Lockable {
    using SafeMath for uint256; 

    event RatioUpdate(uint256 newRatio);
    event GlobalPoolContractUpdated(address prevValue, address newValue);
    event NameAndSymbolChanged(string name, string symbol);
    event OperatorChanged(address prevValue, address newValue);
    event PauseToggled(bytes32 indexed action, bool newValue);
    event BscBridgeContractChanged(address prevValue, address newValue);
    event FeeRecipientChanged(address prevValue, address newValue);
    event RatioThresholdChanged(uint32 prevValue, uint32 newValue);

    uint32 public constant MAX_THRESHOLD = uint32(1e8); // 100000000

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    address private _globalPoolContract;

    // ratio should be base on 1 ether
    // if ratio is 0.9, this variable should be  9e17
    uint256 private _ratio;

    modifier onlyOperator() {
        require(msg.sender == owner() || msg.sender == _operator, "Operator: not allowed");
        _;
    }

    function initialize(string memory name, string memory symbol) public initializer {
        OwnableUpgradeSafe.__Ownable_init();
        __ERC20_init(name, symbol);
        _totalSupply = 0;

        _ratio = 1e18;
    }

    function isRebasing() external pure returns (bool) {
        return false;
    }

    function updateRatio(uint256 newRatio) public onlyOperator {
        _updateRatio(newRatio);
    }

    /*
     * @notice update ratio and claim EL rewards to GlobalPool
     */
    function updateRatioAndClaim(uint256 newRatio) external onlyOperator {
        _updateRatio(newRatio);
        _feeRecipient.claim();
    }

    function _updateRatio(uint256 newRatio) internal {
        (bool valid, string memory reason) = _checkRatioRules(newRatio, _ratio);
        require(valid, reason);
        _ratio = newRatio;
        _ratioUpdateTs = block.timestamp;
        emit RatioUpdate(newRatio);
    }

    function _checkRatioRules(
        uint256 newRatio,
        uint256 oldRatio
    ) internal view returns (bool valid, string memory reason) {
        // initialization of the first ratio -> skip checks
        if (oldRatio == 1e18) {
            return (valid = true, reason);
        }

        if (block.timestamp.sub(_ratioUpdateTs) < 12 hours) {
            return (valid, reason = "AETH: ratio was updated less than 12 hours ago");
        }

        // new ratio should be not greater than a previous one
        if (newRatio > oldRatio) {
            return (valid, reason = "AETH: new ratio cannot be greater than old");
        }

        // new ratio should be in the range [oldRatio - threshold , oldRatio]
        uint256 threshold = oldRatio.mul(_RATIO_THRESHOLD).div(MAX_THRESHOLD);
        if (newRatio < oldRatio.sub(threshold)) {
            return (valid, reason = "AETH: new ratio not in threshold range");
        }

        return (valid = true, reason);
    }

    function repairRatio(uint256 newRatio) public onlyOwner {
        _ratio = newRatio;
        emit RatioUpdate(_ratio);
    }

    function ratio() public view returns (uint256) {
        return _ratio;
    }

    function updateGlobalPoolContract(address globalPoolContract) external onlyOwner {
        address prevValue = _globalPoolContract;
        _globalPoolContract = globalPoolContract;
        emit GlobalPoolContractUpdated(prevValue, globalPoolContract);
    }

    function burn(address account, uint256 amount) external {
        require(msg.sender == address(_bscBridgeContract) || msg.sender == address(_globalPoolContract), 'Not allowed');
        _burn(account, amount);
    }

    function mint(address account, uint256 amount) external returns (uint256) {
        require(msg.sender == address(_bscBridgeContract) || msg.sender == address(_globalPoolContract), 'Not allowed');
        _mint(account, amount);
        return amount;
    }

    function mintApprovedTo(address account, address spender, uint256 amount) external {
        require(msg.sender == address(_bscBridgeContract) || msg.sender == address(_globalPoolContract), 'Not allowed');
        _mint(account, amount);
        _approve(account, spender, amount);
    }

    function symbol() public view override returns (string memory)  {
        return _symbol;
    }

    function name() public view override returns (string memory)  {
        return _name;
    }

    function setNewNameAndSymbol() public onlyOperator {
        _name = "Ankr Eth2 Reward Bearing Bond";
        _symbol = "aETH";
        emit NameAndSymbolChanged(_name, _symbol);
    }

    function setNameAndSymbol(string memory new_name, string memory new_symbol) public onlyOperator {
        _name = new_name;
        _symbol = new_symbol;
        emit NameAndSymbolChanged(_name, _symbol);
    }

    function changeOperator(address operator) public onlyOwner {
        address prevValue = _operator;
        _operator = operator;
        emit OperatorChanged(prevValue, operator);
    }

    function refundPool(address from, uint256 shares) external onlyOwner {
        _transfer(from, _globalPoolContract, shares);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual override whenNotPaused("transfer") {
        super._transfer(sender, recipient, amount);
    }

    /**
     * @dev Allows to transfer any token from this contract.
     * Only operator can call this method.
     * @param token address of the token.
     * @param to address that will receive the tokens from this contract.
     */
    function claimTokens(address token, address to, uint256 amount) external onlyOperator {
        require(IERC20(token).transfer(to, amount), "AETH: transfer failed");
    }

    function sharesToBonds(uint256 amount)
    public
    view
    returns (uint256)
    {
        return MathUtils.multiplyAndDivideFloor(amount, 1 ether, ratio());
    }

    function bondsToShares(uint256 amount)
    public
    view
    returns (uint256)
    {
        return MathUtils.multiplyAndDivideCeil(amount, ratio(), 1 ether);
    }

    modifier whenNotPaused(bytes32 action) {
        require(!_paused[action], "This action currently paused");
        _;
    }

    function togglePause(bytes32 action) public onlyOwner {
        _paused[action] = !_paused[action];
        emit PauseToggled(action, _paused[action]);
    }

    function isPaused(bytes32 action) public view returns (bool) {
        return _paused[action];
    }

    function setBscBridgeContract(address _bscBridge) public onlyOwner {
        address prevValue = _bscBridgeContract;
        _bscBridgeContract = _bscBridge;
        emit BscBridgeContractChanged(prevValue, _bscBridge);
    }

    function setFeeRecipient(address newValue) external onlyOwner {
        require(newValue != address(0), "AETH: zero address");
        emit FeeRecipientChanged(address(_feeRecipient), newValue);
        _feeRecipient = IFeeRecipient(newValue);
    }

    function setRatioThreshold(uint32 newValue) external onlyOwner {
        require(newValue <= MAX_THRESHOLD, "AETH: greater than threshold");
        emit RatioThresholdChanged(_RATIO_THRESHOLD, newValue);
        _RATIO_THRESHOLD = newValue;
    }

    uint256[50] private __gap;

    address private _operator;

    mapping(bytes32 => bool) internal _paused;

    address private _bscBridgeContract;

    IFeeRecipient internal _feeRecipient;

    uint256 private _ratioUpdateTs;
    uint32 public _RATIO_THRESHOLD;
}
