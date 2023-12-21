pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Shakita is ERC20, Ownable {
    using SafeMath for uint256;

    bool public SalesTax;
    bool public AtniWhale;

    address constant public GameRewards = 0x8e2665836732d07b028a99E04d8366dffBe5d6a5;
    address constant public NFTfarm = 0x4EeDF91ad3BAc5283C17Cb6fAba500aFBBfBAad8;
    address constant public Marketing = 0x31Bc316792dB75854dC088a22dF7bD6024FA787c;
    address constant public ShakitaFund = 0xA6fba96eF83d3180D5a97A0788A0f09609846Ff7;
    address constant public Burn = 0xe55EB114834Ce47D787BAf776587381296BdE579;

    address constant public BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address public pair;

    mapping(address => bool) public whiteList;

    constructor(address _issuer) ERC20("Shakita Inu", "Shak") {
        // 9,999,999,999
        ERC20._mint(_issuer, 9999999999000000000000000000);
        

        (address token0, address token1) = address(this) < BUSD ? (address(this), BUSD) : (BUSD, address(this));

        pair = address(uint160(uint256(bytes32(keccak256(abi.encodePacked(
               hex'ff',
               0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73, // factory
               keccak256(abi.encodePacked(token0, token1)),
               hex'00fb7f630766e6a796048ea87d01acd3068e8ff67d078148a3fa3f4a84f69bd5' // init code hash
        ))))));

        whiteList[_issuer] = true;
        whiteList[GameRewards] = true;
        whiteList[NFTfarm] = true;
        whiteList[Marketing] = true;
        whiteList[ShakitaFund] = true;
        whiteList[Burn] = true;
    }

    function setWhiteList(address _who, bool _value) external onlyOwner {
        whiteList[_who] = _value;
    }

    function burn(uint256 _amount) external {
        ERC20._burn(msg.sender, _amount);
    }

    function changeSalesTax() external onlyOwner {
        SalesTax = !SalesTax;
    }

    function changeAtniWhale() external onlyOwner {
        AtniWhale = !AtniWhale;
    }

    // make tax for transfers, make anti whale
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override virtual {
        // no tax and anti whale for whiteList
        if(whiteList[from]) {
            return;
        }

        // no fee for mint and burn action
        if(from == address(0) || to == address(0)) {
            return;
        }

        // apply commission sanctions 10%
        if (SalesTax) {
            uint256 _percent = amount.div(100);
            if (_percent == 0) {
                return;
            }

            ERC20._mint(GameRewards, _percent);
            ERC20._mint(NFTfarm, _percent.mul(2));
            ERC20._mint(Marketing, _percent.mul(3));
            // means buy on pancake router
            if(from == pair) {
                ERC20._mint(ShakitaFund, _percent.mul(4));
            }
            // means sell on pancake router 
            else if(to == pair) {
                ERC20._mint(Burn, _percent.mul(4));
            } 
            // all other transfers
            else {
                ERC20._mint(ShakitaFund, _percent.mul(4));
            }
            ERC20._burn(to, _percent.mul(10));
        }

        // because admins can have more then limit
        if(whiteList[to]) {
            return;
        }

        // apply anti whale sanctions
        if(AtniWhale) {
            // 300m
            require(ERC20.balanceOf(to) <= 300000000000000000000000000, "balanceExceedsLimit");
            // 30m
            require(amount <= 30000000000000000000000000, "amountExceedsLimit");
        }
    }
}