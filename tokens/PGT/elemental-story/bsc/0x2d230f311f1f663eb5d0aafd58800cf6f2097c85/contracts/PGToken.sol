// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PGToken is ERC20, Ownable {
    event MinterTransferred(address indexed previousMinter, address indexed newMinter);
    event TokensReleased(address indexed _to, uint indexed releasedAmount);

    uint256 public immutable maxSupply;
    uint256 public immutable monthlyReleaseAmount;
    uint256 public lockedAmount;
    uint256 public nextReleaseTime;
    address public minter;

    constructor(address _initialOwner, address _initialMinter)
        ERC20("PUZZLE GAME GOVERNANCE TOKEN", "PGT")
        Ownable(_initialOwner)
    {
        minter = _initialMinter;
        maxSupply = 6_000_000_000 * 1e18;
        monthlyReleaseAmount = 120_000_000 * 1e18;
        lockedAmount = maxSupply - monthlyReleaseAmount;
        _mint(_initialOwner, monthlyReleaseAmount);
        nextReleaseTime = block.timestamp + 30 days;
    }

    modifier onlyAuth() {
        require(
            msg.sender == minter || msg.sender == owner(),
            "Caller is not authorized."
        );
        _;
    }

    function releaseTokens(address _to) external onlyAuth returns (bool) {
        require(nextReleaseTime <= block.timestamp, "Not yet releasable");
        require(totalSupply() < maxSupply, "No tokens to release");
        lockedAmount -= monthlyReleaseAmount;
        _mint(_to, monthlyReleaseAmount);
        nextReleaseTime += 30 days;
        emit TokensReleased(_to, monthlyReleaseAmount);
        return true;
    }

    function changeMinter(address _newMinter) external onlyOwner() {
        require(_newMinter != address(0), "Invalid address: address(0x0)");
        address oldMinter = minter;
        minter = _newMinter;
        emit MinterTransferred(oldMinter, minter);
    }
}
