// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract NXTT is ERC20, ERC20Snapshot, Ownable, Pausable, ERC20Permit, ERC20Votes, ReentrancyGuard {
    address public distributionContract;
    mapping (address => bool) canSnapshot;
    mapping (address => bool) canBurn;
    address public teamAddress;
    address public idoAddress;
    address public DAOAddress;
    mapping (address => bool) public isDex;
    mapping (address => bool) public buyWhitelist;
    mapping (address => bool) public sellWhitelist;

    // fees use 3 decimals
    uint256 public buyFee;
    uint256 public sellFee;
    uint256 public maxDexTransfer;

    event DexSet(address indexed a, bool indexed v);
    event BuyFeeChanged(uint256 indexed fee);
    event SellFeeChanged(uint256 indexed fee);
    event TeamAddressChanged(address indexed addr);
    event DAOAddressChanged(address indexed addr);
    event DexLimitChanged(uint256 indexed amount);

    constructor(
      address _distributionContract,
      address _teamAddress,
      address _DAOAddress
    ) ERC20("NextEarthToken", "NXTT") ERC20Permit("NextEarthToken") {
        distributionContract = _distributionContract;

        teamAddress = _teamAddress;
        idoAddress = distributionContract;
        DAOAddress = _DAOAddress;
        _mint(teamAddress, 57e9 * 10** decimals());
        _mint(idoAddress, 3e9 * 10** decimals());
        canSnapshot[msg.sender] = true;
    }

    function snapshot() public {
        require(canSnapshot[msg.sender], "sender cannot snapshot");
        _snapshot();
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override(ERC20, ERC20Snapshot)
    {
        super._beforeTokenTransfer(from, to, amount);
    }
    function transfer(address to, uint256 amount) public override(ERC20) 
    returns (bool) {
      uint256 fee = 0;
      if(maxDexTransfer > 0 && (isDex[msg.sender] || isDex[to])) {
        require(amount < maxDexTransfer, "DEX transfer limit reached");
      }
      if(isDex[msg.sender] && buyFee > 0 && !buyWhitelist[to]) {
        fee += amount * buyFee / 1000;
      }
      if(isDex[to] && sellFee > 0 && !sellWhitelist[msg.sender]) {
        fee += amount * sellFee / 1000;
      }
      if (fee > 0) {
        require(super.transfer(address(this), fee), 'fee transaction failed');
      }
      return super.transfer(to, amount - fee);
    }

    function transferFrom(address from, address to, uint256 amount) public override(ERC20) 
    returns (bool) {
      uint256 fee = 0;
      if(isDex[from] && buyFee > 0 && !buyWhitelist[to]) {
        fee += amount * buyFee / 1000;
      }
      if(isDex[to] && sellFee > 0 && !sellWhitelist[from]) {
        fee += amount * sellFee / 1000;
      }
      if (fee > 0) {
        require(super.transferFrom(from, address(this), fee), 'fee transaction failed');
      }
      return super.transferFrom(from, to, amount - fee);
    }

    function burn(uint256 amount) external {
      require(canBurn[msg.sender], "permission denied");
      _burn(msg.sender, amount);
    }
    // The following functions are overrides required by Solidity.
    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal nonReentrant
        override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }
	
    function setSnapshotCapability(address addr, bool val) external onlyOwner {
      require(addr != address(0));
      canSnapshot[addr] = val;
    }
    
    function setBurnCapability(address addr, bool val) external onlyOwner {
      require(addr != address(0));
      canBurn[addr] = val;
    }

    function setDex(address _addr, bool val) external onlyOwner {
      require(_addr != address(0));
      isDex[_addr] = val;
      emit DexSet(_addr, val);
    }
    
    function setBuyFee(uint256 _fee) external onlyOwner {
      require(_fee < 1000, 'fee should be 3 decimals');
      buyFee = _fee;
      emit BuyFeeChanged(_fee);
    }

    function setSellFee(uint256 _fee) external onlyOwner {
      require(_fee < 1000, 'fee should be 3 decimals');
      sellFee = _fee;
      emit SellFeeChanged(_fee);
    }
    
    function setTeamAddress(address _addr) external onlyOwner {
      require(_addr != address(0));
      teamAddress = _addr;
      emit TeamAddressChanged(_addr);
    }

    function setDAOAddress(address _addr) external onlyOwner {
      require(_addr != address(0));
      DAOAddress = _addr;
      emit DAOAddressChanged(_addr);
    }

    function whiteList(address _addr, bool buy, bool sell) external onlyOwner {
      require(_addr != address(0));
      buyWhitelist[_addr] = buy;
      sellWhitelist[_addr] = sell;
    }
    
    function setDexLimit(uint256 amount) external onlyOwner {
      maxDexTransfer = amount;
      emit DexLimitChanged(amount);
    }

    function withdrawMatic() external onlyOwner {
      (bool ok,) = msg.sender.call{value: address(this).balance}('');
      require(ok, 'withdraw transaction failed');
    }

    function withdrawNXTT() external onlyOwner {
      uint256 balance = balanceOf(address(this));
      SafeERC20.safeTransfer(IERC20(address(this)), msg.sender, balance);
    }

		receive() external payable {
		}
}

