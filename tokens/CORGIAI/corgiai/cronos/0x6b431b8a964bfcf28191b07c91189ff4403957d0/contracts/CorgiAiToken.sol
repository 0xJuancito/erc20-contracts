pragma solidity =0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CorgiAiToken is Ownable, ERC20 {

    uint256 public constant MAX_TOTAL_SUPPLY = 500_000_000_000 ether;

    uint256 public immutable distributionTimestamp;

    event MintLockedSupply(uint256 tokenAmount);

    constructor(uint256 _initialSupply) ERC20("CorgiAI", "CORGIAI") {
        require(_initialSupply <= MAX_TOTAL_SUPPLY, "Total supply exceeds maximum allowed");
        _mint(msg.sender, _initialSupply);
        distributionTimestamp = block.timestamp;
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function mintLockedSupply(
        address[] calldata _teamAddresses,
        uint256[] calldata _teamAmounts
    ) external onlyOwner {
        require(block.timestamp >= distributionTimestamp + 365 days, "Not ready to unlock");
        require(_teamAddresses.length == _teamAmounts.length, "Inconsistent param length");

        uint256 tokenAmount;
        for (uint256 i; i < _teamAddresses.length; ++i) {
            _mint(_teamAddresses[i], _teamAmounts[i]);
            tokenAmount += _teamAmounts[i];
        }

        require(MAX_TOTAL_SUPPLY >= totalSupply(), "Minting exceed max total supply");

        emit MintLockedSupply(tokenAmount);
    }

    function unmintedSupply() external view returns (uint256) {
        return MAX_TOTAL_SUPPLY - totalSupply();
    }
}
