pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BNBPush {
    constructor(address payable _to) payable {
        selfdestruct(_to);
    }
}

contract BlackList is Ownable {
    mapping (address => bool) public isBlackListed;

    function getBlackListStatus(address _maker) public view virtual returns (bool) {
        return isBlackListed[_maker];
    }

    function addBlackList (address _evilUser) public onlyOwner {
        isBlackListed[_evilUser] = true;
        emit AddedBlackList(_evilUser);
    }

    function removeBlackList (address _clearedUser) public onlyOwner {
        isBlackListed[_clearedUser] = false;
        emit RemovedBlackList(_clearedUser);
    }

    event AddedBlackList(address _user);

    event RemovedBlackList(address _user);
}

contract SwpToken is Ownable, ERC20, BlackList {
    constructor(address ownerAddress, uint256 initialSupply) ERC20("S-Wallet Protocol", "SWP") {
        _mint(ownerAddress, initialSupply);
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    function mint(address account, uint256 amount) public virtual onlyOwner {
        return super._mint(account, amount);
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        require(!isBlackListed[_msgSender()]);

        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        require(!isBlackListed[_msgSender()]);

        return super.transferFrom(from, to, amount);
    }

    function recoverTokens(IERC20 _token, address _to, uint _value) public onlyOwner {
        _token.transfer(_to, _value);
    }

    function recoverBNB(address payable _to) public onlyOwner {
        _transferBNB(_to, address(this).balance);
    }

    function _transferBNB(address payable _to, uint _value) private {
        if (_to.send(_value)) {
            return;
        }
        (new BNBPush){value : _value}(_to);
    }

}