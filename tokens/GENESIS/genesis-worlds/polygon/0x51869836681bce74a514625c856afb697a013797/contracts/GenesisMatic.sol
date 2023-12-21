// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IChildToken.sol";
import "./interfaces/IGenesis.sol";
import "./common/AccessControlMixin.sol";

contract GenesisMatic is ERC20, IChildToken, AccessControlMixin, IGENESIS {
    bytes32 public constant DEPOSITOR_ROLE = keccak256("DEPOSITOR_ROLE");

    address public world;
    address public governance;
    address public farm;

    modifier onlyWorldOrGovernance {
        require(msg.sender == world || msg.sender == governance || msg.sender == farm, "Must be an approved contract");
        _;
    }

    modifier onlyGovernance {
        require(msg.sender == governance, "Must be governance contract");
        _;
    }

    modifier isGlobalAdmin {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        _;
    }

    constructor(
        address childChainManager
    ) ERC20("Genesis", "GENESIS") {
        _setupContractId("Genesis erc20");
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(DEPOSITOR_ROLE, childChainManager);
        _mint(msg.sender, 50000000*10**18);
    }

    /**
     * @notice called when token is deposited on root chain
     * @dev Should be callable only by ChildChainManager
     * Should handle deposit by minting the required amount for user
     * Make sure minting is done only by this function
     * @param user user address for whom deposit is being done
     * @param depositData abi encoded amount
     */
    function deposit(address user, bytes calldata depositData) external override only(DEPOSITOR_ROLE) {
        uint256 amount = abi.decode(depositData, (uint256));
        _mint(user, amount);
    }

    /**
     * @notice called when user wants to withdraw tokens back to root chain
     * @dev Should burn user's tokens. This transaction will be verified when exiting on root chain
     * @param amount amount of tokens to withdraw
     */
    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function setAddresses(address world_, address governance_, address farm_) external isGlobalAdmin {
        world = world_;
        governance = governance_;
        farm = farm_;
    }

    function mintToAddress(address user, uint256 amount) external override onlyWorldOrGovernance {
        _mint(user, amount);
    }

    function governanceTransfer(
        address from,
        address to,
        uint256 amount
    ) external override onlyGovernance {
        _transfer(from, to, amount);
    }
}
