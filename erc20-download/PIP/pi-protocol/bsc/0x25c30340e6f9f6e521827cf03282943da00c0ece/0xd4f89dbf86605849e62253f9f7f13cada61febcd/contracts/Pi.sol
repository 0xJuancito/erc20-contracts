// SPDX-License-Identifier: J-J-J-JENGA!!!
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "./openzeppelinupgradeable/token/ERC20/ERC20Upgradeable.sol";
import "./openzeppelinupgradeable/access/OwnableUpgradeable.sol";
import "./openzeppelinupgradeable/math/SafeMathUpgradeable.sol";
import "./openzeppelinupgradeable/token/ERC20/SafeERC20Upgradeable.sol";

import "./interfaces/IPiTransferGate.sol";
import "./interfaces/IGatedERC20.sol";
import "./interfaces/IEventGate.sol";


contract Pi is Initializable, ERC20Upgradeable, OwnableUpgradeable
{

    using SafeMathUpgradeable for uint256;

    IPiTransferGate public transferGate;
    IEventGate public eventGate;
    address public LPAddress; // axBNB <-> Pi SLP


    mapping(address=>bool) IGNORED_ADDRESSES;
    address public piZapper;
    address public circleNFTZapper;
    event TransferGateSet(address transferGate, address eventGate);
    event LPAddressSet(address _LPAddress);
    event ZapperSet(address piZapper, address circleNFTZapper);

    function initialize()  public initializer  {

        __Ownable_init_unchained();
        __ERC20_init("Pi-Protocol","PIP");

        _mint(0x416760a2D78D5Bdc6841851A0d48F2787Bc23d61, 600000 ether); 
    }


    function setIgnoredAddressBulk(address[] memory _ignoredAddressBulk, bool ignore)external onlyOwner{
        
        for(uint i=0;i<_ignoredAddressBulk.length;i++){
            address _ignoredAddress = _ignoredAddressBulk[i];
            IGNORED_ADDRESSES[_ignoredAddress] = ignore;
        }
    }

    function setIgnoredAddresses(address _ignoredAddress, bool ignore)external onlyOwner{
        IGNORED_ADDRESSES[_ignoredAddress]=ignore;
    }
    
    function setTransferGates(IPiTransferGate _transferGate, IEventGate _eventGate) public onlyOwner()
    {
        transferGate = _transferGate;
        eventGate = _eventGate;
        emit TransferGateSet(address(transferGate),address(eventGate));
    }

    function setLPAddress(address _LPAddress) public onlyOwner()
    {
        require(_LPAddress != address(0), "Pi: _LPAddress cannot be zero address");
        LPAddress = _LPAddress;
        emit LPAddressSet(_LPAddress);
    }


    function setZapper(address _piZapper, address _circleNFTZapper) external onlyOwner() {
        require(_piZapper != address(0), "Pi: _piZapper cannot be zero address");
        require(_circleNFTZapper != address(0), "Pi: _circleNFTZapper cannot be zero address");

        piZapper = _piZapper;
        circleNFTZapper = _circleNFTZapper;   

        emit ZapperSet(piZapper, circleNFTZapper);     
    }

 
    function _transfer(address sender, address recipient, uint256 amount) internal virtual override 
    {
        require(sender != address(0), "Pi: transfer from the zero address");
        require(recipient != address(0), "Pi: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        IPiTransferGate _transferGate = transferGate;
        uint256 remaining = amount;
        _balances[sender] = _balances[sender].sub(amount, "Pi: transfer amount exceeds balance");

        if(sender == piZapper && recipient != address(eventGate) && recipient != LPAddress && recipient != address(transferGate) && recipient != circleNFTZapper) 
        {   
            _balances[address(eventGate)] = _balances[address(eventGate)].add(remaining);
            emit Transfer(sender, address(eventGate), remaining);
            eventGate.handleZap(sender, recipient, remaining); // to lock and transfer remaining Pi after zapRates to recipient
        }

        else if(sender == LPAddress && recipient != address(eventGate) && recipient != piZapper && recipient != circleNFTZapper)
        {   
            if (address(_transferGate) != address(0)) {
                (uint256 burn, TransferGateTarget[] memory targets) = _transferGate.handleTransfer(msg.sender, sender, recipient, amount);            
                if (burn > 0) {
                    remaining = remaining.sub(burn, "Pi: Burn too much for zapper");
                    _totalSupply = _totalSupply.sub(burn);
                    emit Transfer(sender, address(0), burn);
                }
                for (uint256 x = 0; x < targets.length; ++x) {
                    (address dest, uint256 amt) = (targets[x].destination, targets[x].amount);
                    remaining = remaining.sub(amt, "Pi: Transfer too much for zapper");
                    _balances[dest] = _balances[dest].add(amt);
                    emit Transfer(sender, dest, amt);
                }
            }
            _balances[address(eventGate)] = _balances[address(eventGate)].add(remaining);
            emit Transfer(sender, address(eventGate), remaining);
            eventGate.handleZap(sender, recipient, remaining); // to lock and transfer remaining Pi after zapRates to recipient
        }
        else 
        if(IGNORED_ADDRESSES[recipient]){// || sender == address(eventGate)) {
            _balances[recipient] = _balances[recipient].add(amount);
            emit Transfer(sender, recipient, amount);
        } 
        else
        {
            if (address(_transferGate) != address(0)) {
                (uint256 burn, TransferGateTarget[] memory targets) = _transferGate.handleTransfer(msg.sender, sender, recipient, amount);            
                if (burn > 0) {
                    remaining = remaining.sub(burn, "Pi: Burn too much");
                    _totalSupply = _totalSupply.sub(burn);
                    emit Transfer(sender, address(0), burn);
                }
                for (uint256 x = 0; x < targets.length; ++x) {
                    (address dest, uint256 amt) = (targets[x].destination, targets[x].amount);
                    remaining = remaining.sub(amt, "Pi: Transfer too much");
                    _balances[dest] = _balances[dest].add(amt);
                    emit Transfer(sender, dest, amt);
                }
            }
            _balances[recipient] = _balances[recipient].add(remaining);
            emit Transfer(sender, recipient, remaining);

        }
    }
}

