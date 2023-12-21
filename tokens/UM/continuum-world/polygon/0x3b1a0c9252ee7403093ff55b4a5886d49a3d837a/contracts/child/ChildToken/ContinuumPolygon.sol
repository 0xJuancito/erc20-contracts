pragma solidity 0.6.6;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControlMixin} from "../../common/AccessControlMixin.sol";
import {IChildToken} from "./IChildToken.sol";
import {NativeMetaTransaction} from "../../common/NativeMetaTransaction.sol";
import {ContextMixin} from "../../common/ContextMixin.sol";


contract ContinuumPolygon is
    ERC20,
    IChildToken,
    AccessControlMixin,
    NativeMetaTransaction,
    ContextMixin
{
    bytes32 public constant DEPOSITOR_ROLE = keccak256("DEPOSITOR_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    constructor(address childChainManager) public ERC20("Continuum", "UM") {
        _setupContractId("Continuum");
        _setupDecimals(18);
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(BURNER_ROLE, _msgSender());
        _setupRole(DEPOSITOR_ROLE, childChainManager);
        _initializeEIP712("Continuum");
        _mint(_msgSender(), 3 * (10**27));
    }

    // This is to support Native meta transactions
    // never use msg.sender directly, use _msgSender() instead
    function _msgSender()
        internal
        override
        view
        returns (address payable sender)
    {
        return ContextMixin.msgSender();
    }

    /// @notice This method can be used by the owner to extract mistakenly sent tokens to this contract.
    /// @param _token The address of the token contract that you want to recover
    ///  set to 0 in case you want to extract ether.
    function claimTokens(address _token) external only(DEFAULT_ADMIN_ROLE) {
        if (_token == address(0)) {
            msg.sender.transfer(address(this).balance);
            return;
        }

        ERC20 token = ERC20(_token);
        uint balance = token.balanceOf(address(this));
        token.transfer(msg.sender, balance);
        emit ClaimedTokens(_token, balance);
    }

    /**
    * @notice called when token is deposited on root chain
    * @dev Should be callable only by ChildChainManager
    * Should handle deposit by minting the required amount for user
    * Make sure minting is done only by this function
    * @param user user address for whom deposit is being done
    * @param depositData abi encoded amount
    */
    function deposit(address user, bytes calldata depositData)
        external
        override
        only(DEPOSITOR_ROLE)
    {
        uint256 amount = abi.decode(depositData, (uint256));
        _mint(user, amount);
    }

    /**
    * @notice called when user wants to withdraw tokens back to root chain
    * @dev Should burn user's tokens. This transaction will be verified when exiting on root chain
    * @param amount amount of tokens to withdraw
    */
    function withdraw(uint256 amount) external {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev Minting can be done as per requirement
     * @param user user for whom tokens are being minted
     * @param amount amount of token to mint
     */
    function mint(address user, uint256 amount) public only(MINTER_ROLE) {
        _mint(user, amount);
    }

    /**
     * @dev Burning can be done as per requirement
     * @param user user for whom tokens are being burned
     * @param amount amount of token to mint
     */
    function burn(address user, uint256 amount) public only(BURNER_ROLE) {
        _burn(user, amount);
    }

    event ClaimedTokens(
        address token,
        uint amount
    );

}
