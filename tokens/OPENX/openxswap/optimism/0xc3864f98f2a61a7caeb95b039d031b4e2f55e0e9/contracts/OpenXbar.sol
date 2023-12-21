// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Snapshot.sol";

interface IMC{
	function deposit(uint256 _pid, uint256 _amount,address _to) external;
    function harvest(uint256 pid, address to) external;
}

// OpenXBar is the second coolest bar in town (after Sushi (mad respect)). You come in with some OpenX, and leave with more! The longer you stay, the more OpenX you get.
//
// This contract handles swapping to and from xOpenX, OpenXSwap's staking token.
contract OpenXBar is ERC20("OpenXbar", "xOpenX"), ERC20Snapshot{
    using SafeMath for uint256;
    IERC20 public OpenX;
    IMC public masterchef;
    IERC20 dummyToken;
    address public snapAdmin;
    uint256 public lockEnd;

    // Define the OpenX token contract
    constructor(IERC20 _OpenX, IERC20 _dummyToken) public {
        OpenX = _OpenX;
        dummyToken = _dummyToken;
       	snapAdmin = msg.sender;
        lockEnd = block.timestamp + 180 days;
    }

    function changeSnapshotAdmin(address _admin) public {
    	require(msg.sender == snapAdmin, "Unauthorized");
    	snapAdmin = _admin;
    }

    function snapshot() public {
    	require(msg.sender == snapAdmin, "Unauthorized");
        _snapshot();
    }

    uint private unlocked = 1;
    //reentrancy guard for deposit/withdraw
    modifier lock() {
        require(unlocked == 1, 'OpenXBar LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    // Enter the bar. Pay some OPENXs. Earn some shares.
    // Locks OpenX and mints xOpenX
    function enter(uint256 _amount) public lock {
    	_harvestOpenX();
        // Gets the amount of OpenX locked in the contract
        uint256 totalOpenX = OpenX.balanceOf(address(this));
        // Gets the amount of xOpenX in existence
        uint256 totalShares = totalSupply();
        // If no xOpenX exists, mint it 1:1 to the amount put in
        if (totalShares == 0 || totalOpenX == 0) {
            _mint(msg.sender, _amount);
        } 
        // Calculate and mint the amount of xOpenX the OpenX is worth. The ratio will change overtime, as xOpenX is burned/minted and OpenX deposited + gained from fees / withdrawn.
        else {
            uint256 what = _amount.mul(totalShares).div(totalOpenX);
            _mint(msg.sender, what);
        }
        // Lock the OpenX in the contract
        OpenX.transferFrom(msg.sender, address(this), _amount);
    }

    function _harvestOpenX() internal {
	    masterchef.harvest(0, address(this));
    }

    function init(IMC _masterchef) public {
        require(address(masterchef) == address(0));
        masterchef = _masterchef;
        uint256 balance = dummyToken.balanceOf(msg.sender);
        require(balance != 0, "Balance must exceed 0");
        dummyToken.transferFrom(msg.sender, address(this), balance);
        dummyToken.approve(address(masterchef), balance);
        masterchef.deposit(0, balance, address(this));
    }

    // Leave the bar. Claim back your OPENXs.
    // Unlocks the staked + gained OpenX and burns xOpenX
    function leave(uint256 _share) public lock {
        require(block.timestamp >= lockEnd, "Tokens still locked.");
    	_harvestOpenX();
        // Gets the amount of xOpenX in existence
        uint256 totalShares = totalSupply();
        // Calculates the amount of OpenX the xOpenX is worth
        uint256 what = _share.mul(OpenX.balanceOf(address(this))).div(totalShares);
        _burn(msg.sender, _share);
        OpenX.transfer(msg.sender, what);
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Snapshot)
    {
        super._beforeTokenTransfer(from, to, amount);
    }

}