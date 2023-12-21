pragma solidity >=0.6.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PolkaBridgeMemeToken is ERC20, ERC20Detailed, ERC20Burnable {
    constructor(uint256 initialSupply)
        public
        ERC20Detailed("The Corgi of PolkaBrige", "CORGIB", 18)
    {
        _mint(msg.sender, initialSupply);
    }

    function withdrawErc20(IERC20 token) public {
        token.transfer(tokenOwner, token.balanceOf(address(this)));
    }
}
