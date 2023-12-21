//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../../interfaces/IA3SToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract A3SToken is IA3SToken, ERC20, Ownable {
    uint256 public total_maxSupply = 1 * (10**9) * (10**18);
    uint256 public total_q2earnSupply = total_maxSupply * 90 / 100; // 90% of total max supply is used for queue to earn gaming
    uint256 public total_TreasurySupply = total_maxSupply * 95 / 1000; // 9.5% of total max supply is used for treasury 
    uint256 public total_ProjectPartySupply = total_maxSupply * 5 / 1000; // 0.5% of total max supply is used for project 
    uint256 public current_queue2earnSupply;
    address A3STreasury;
    address A3SProjectParty;
    address bridge;
    mapping(address => bool) public governors;

    event Mint(address to, uint256 amount);
    event Burn(address account, uint256 amount);
    event UpdateGovernors(address newGovernor, bool status);

    modifier ONLY_GOV() {
        require(governors[msg.sender], "A3S: caller is not governor");
        _;
    }

    modifier onlyBridge() {
        require(msg.sender == bridge, "A3S: not bridge");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        address _A3STreasury,
        address _A3SProjectParty
    ) ERC20(_name, _symbol) {
        A3STreasury = _A3STreasury;
        A3SProjectParty = _A3SProjectParty;
        governors[msg.sender] = true;
        _mint(A3STreasury, total_TreasurySupply);
        _mint(A3SProjectParty, total_ProjectPartySupply);
    }

    //Queue to Play Mint
    //ONLY Governors addresss could mint
    function mint(address to, uint256 amount) external ONLY_GOV {
        require(current_queue2earnSupply + amount <= total_q2earnSupply, "A3S: Queue To Earn $AA token mint exceed the maximum supply");
        _mint(to, amount);
        current_queue2earnSupply += amount;
        emit Mint(to, amount);
    }

    // Leave the function for future Bridge feature
    // Mint privilege is limited to Bridge contract address ONLY 
    function bridgeMint(address owner, uint256 amount) external onlyBridge returns(bool) {
        _mint(owner, amount);
        return true;
    }
    function bridgeBurn(address owner, uint256 amount) external onlyBridge returns(bool) {
        _burn(owner, amount);
        return true;
    }

    function setBridgeAccess(address bridgeAddr) external onlyOwner {
        bridge = bridgeAddr;
    }

    function updateTotalMaxSupply(uint256 new_totalMaxSupply) public onlyOwner {
        total_maxSupply = new_totalMaxSupply;
    }

    //Update governors
    function updateGovernors(address newGovernor, bool status) public onlyOwner {
        governors[newGovernor] = status;
        emit UpdateGovernors(newGovernor, status);
    }
}
