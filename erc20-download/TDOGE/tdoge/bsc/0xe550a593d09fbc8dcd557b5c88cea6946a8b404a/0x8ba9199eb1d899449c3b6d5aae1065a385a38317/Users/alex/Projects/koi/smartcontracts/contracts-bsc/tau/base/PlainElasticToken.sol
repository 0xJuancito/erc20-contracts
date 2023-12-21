// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;

import "../../libraries/PeggyToken.sol";
import "../../libraries/SafeMathInt.sol";

contract PlainElasticToken is PeggyToken{

    address public monetaryPolicy;
    uint256 public rebaseStartTime;

    bool public started;
    event LogRebase(uint256 indexed epoch, uint256 totalSupply);
    event LogMonetaryPolicyUpdated(address monetaryPolicy);
    modifier onlyAfterRebaseStart() {
        require(now >= rebaseStartTime);
        _;
    }
    modifier validRecipient(address to) {
        require(to != address(this));
        _;
    }
    modifier onlyMonetaryPolicy() {
        require(msg.sender == monetaryPolicy);
        _;
    }
    function initialize(string memory name, string memory symbol) override public virtual initializer {
        initialize(name, symbol,_msgSender());
        pause();
    }
    
    function startWithInitialSupply(uint256 initialSupply,uint256 rebaseStartTime_) public onlyOwner{
        require(!started,"started");
        require(initialSupply>1,"initalSupply should >1");
        _unpause();
        rebaseStartTime = rebaseStartTime_;

        _mint(owner(), initialSupply);
        started = true;
    }
    // authed method
    function setMonetaryPolicy(address plolicy) external{
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),"have no right");
        monetaryPolicy = plolicy;
        emit LogMonetaryPolicyUpdated(plolicy);
    }

    function __expandBurn(address account, uint256 amount) internal virtual {
        _burn(account, amount);
    }
    function __expandTransferDirect(address sender, address recipient, uint256 amount) internal virtual{
        _transferDirect(sender, recipient, amount);
    }

    function __expandTransfer(address sender, address recipient, uint256 amount) internal virtual {       
        __expandBeforeTokenTransfer(sender,recipient,amount);
        _transfer(sender, recipient, amount);
    }

    function __expandBeforeTokenTransfer(address account, address to, uint256 amount) internal virtual {

    }
    function _beforeTokenTransfer(address from, address to, uint256 amount) validRecipient(to) internal virtual override(PeggyToken) {
        super._beforeTokenTransfer(from, to, amount);
        __expandBeforeTokenTransfer(from,to,amount);
    }
    uint256[50] private __gap;
}