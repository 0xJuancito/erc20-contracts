pragma solidity ^0.6.2;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "@opengsn/gsn/contracts/BaseRelayRecipient.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Burnable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Capped.sol";

contract CEEK is ERC20('CEEK', 'CEEK'), ERC20Burnable, Ownable, ERC20Capped(1000000000e18), BaseRelayRecipient {

    using SafeMath for uint;

    bytes32 public constant TokenSignature = "CEEK_BRIDGE_TOKEN";

    address public gate;

    function setGate(address _gate) public onlyOwner {
        gate = _gate;
    }
    
    function setTrustedForwarder(address _trustedForwarder) public onlyOwner {
        trustedForwarder = _trustedForwarder;
    }

    function mint(address account, uint256 amount) public {
        require(_msgSender() == gate, "FORBIDDEN");
        _mint(account, amount);
    }

    function versionRecipient() external override view returns (string memory) {
        return '1';
    }

    function _msgData() internal override(Context, BaseRelayRecipient) virtual view returns (bytes memory) {
        return BaseRelayRecipient._msgData();
    }

    function _msgSender() internal override(Context, BaseRelayRecipient) virtual view returns (address payable ret) {
        return BaseRelayRecipient._msgSender();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override(ERC20, ERC20Capped) {
        return ERC20Capped._beforeTokenTransfer(from, to, amount);
    }

}