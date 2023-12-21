pragma solidity ^0.6.4;

import "./ERC20PresetMinterPauser.sol";

contract ERC20PresetMinterPauserLimiter is ERC20PresetMinterPauser {
    constructor(string memory name, string memory symbol, uint8 decimals) public ERC20PresetMinterPauser(name, symbol, decimals) {}

    bool public shouldLimitTransfers = true;
    uint256 public limitTransfersDeadline = now + 60 * 60 * 24 * 60;
    uint256 public timeLimit = 3600;
    uint256 public amountLimit = 1000 * 1e18;
    address public quickSwapRouter = address(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);
    address public quickSwapPair = address(0);
    mapping (address => uint256) public lastTransfer;

    function limitTransfers(address sender, address recipient, uint256 amount) private {
        if (!shouldLimitTransfers) return;
        if (recipient != quickSwapRouter && recipient != quickSwapPair) return;
        require(amount <= amountLimit, "Transfer amount limit");
        require(now - lastTransfer[sender] >= timeLimit, "Transfer time limit");
        lastTransfer[sender] = now;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        limitTransfers(sender, recipient, amount);
        return super.transferFrom(sender, recipient, amount);
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        limitTransfers(_msgSender(), recipient, amount);
        return super.transfer(recipient, amount);
    }

    modifier onlyAdmin {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "ERC20PresetMinterPauser: must have admin role");
        _;
    }

    function enableTransferLimit() public {
        require(now >= limitTransfersDeadline, "Public enabling tranfers not available yet");
        shouldLimitTransfers = false;
    }

    function setShouldLimitTransfers(bool _shouldLimitTransfers) public onlyAdmin {
        require(now < limitTransfersDeadline, "Admin disabling transfers expired");
        shouldLimitTransfers = _shouldLimitTransfers;
    }

    function setTransfersTimeLimit(uint256 _timeLimit) public onlyAdmin {
        timeLimit = _timeLimit;
    }

    function setTransfersAmountLimit(uint256 _amountLimit) public onlyAdmin {
        amountLimit = _amountLimit;
    }

    function setQuickSwapRouter(address _quickSwapRouter) public onlyAdmin {
        quickSwapRouter = _quickSwapRouter;
    }

    function setQuickSwapPair(address _quickSwapPair) public onlyAdmin {
        quickSwapPair = _quickSwapPair;
    }
}
