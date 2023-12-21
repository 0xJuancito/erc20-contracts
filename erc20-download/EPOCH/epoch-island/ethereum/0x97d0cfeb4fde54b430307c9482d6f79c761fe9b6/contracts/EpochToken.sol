pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract EpochToken is ERC20, Ownable, ERC20Permit, ERC20Burnable {

    uint256 public mintCapStartTs;
    uint256 public mintableUntilMintCap;

    constructor(address _newOwner) ERC20("Epoch", "EPOCH") ERC20Permit("Epoch") {
        _transferOwnership(_newOwner);
        _mint(owner(), 100000000*(10**18));
    }

    // @notice Returns timestamp of when minting cap ends
    function mintCapEndTs() public view returns(uint256) {
        return mintCapStartTs + 604800;
    }

    // @notice Allows Owner to mint tokens
    // @dev No more than 10% of the total supply can be minted each week
    function mint(address to, uint256 amount) public onlyOwner {
        if(block.timestamp >= mintCapEndTs()) {
            mintCapStartTs = block.timestamp;
            mintableUntilMintCap = (totalSupply() * 1000) / 10000;
        }

        // @dev This is decorative and could be removed with mint cap still enforced
        require(amount <= mintableUntilMintCap, "MINT CAP");

        mintableUntilMintCap -= amount;
        _mint(to, amount);
    }
}
