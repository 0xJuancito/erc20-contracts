// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ECDSA} from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {HelloBridgeStore} from "./HelloBridgeStore.sol";
/* -------------------------------------------------------------------------- */
/*                                   errors                                   */
/* -------------------------------------------------------------------------- */
error SignerNotWithdrawSigner();
error NoAmountToWithdraw();
error CannotBridgeToUnsupportedChain();
error Paused();
error NotPaused();
error ZeroAddress();

///@notice The owner will always be a multisig wallet.


/* -------------------------------------------------------------------------- */
/*                                 HelloBridge                                */
/* -------------------------------------------------------------------------- */
/**
 * @title A cross-chain bridge for HelloToken
 * @author 0xSimon
 * @notice It is recommended to use the provided UI to bridge your tokens from chain A to chain B
 * @dev Assumptions:
 *     - On chains that this contract is deployed to (besides the mainnet), the entire supply of HelloToken will be minted and sent to this contract.
 */
contract HelloBridge is Ownable {
    using ECDSA for bytes32;

    /* -------------------------------------------------------------------------- */
    /*                                   events                                   */
    /* -------------------------------------------------------------------------- */
    event Deposit(address indexed sender, uint256 amount, uint256 chainId);
    event Claim(address indexed sender, uint256 totalDepositedOnOtherChain, uint256 otherChainId);
    event SupportedChainChanged(uint256 chainID, bool isSupported);
    event SupportedChainsChanged(uint256[] chainIDs, bool isSupported);
    event WithdrawSigner1Changed(address signer);
    event WithdrawSigner2Changed(address signer);
    event PausedChanged(bool depositPaused, bool claimPaused);
    event BridgeStoreChanged(address store);

    /* -------------------------------------------------------------------------- */
    /*                                  constants                                 */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice The HelloToken contract
     */
    IERC20 public immutable HELLO_TOKEN;

    /* -------------------------------------------------------------------------- */
    /*                                   states                                   */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice The signer providing signatures for claiming tokens on the destination chain
     */
    address public withdrawSigner1;
    address public withdrawSigner2;

    /**
     * @notice Storage contract for deposits and withdrawals numbers
     */
    HelloBridgeStore public store;

    /**
     * @notice A mapping to store which destination chains are supported
     */
    mapping(uint256 => bool) public supportedChains;

    bool public depositPaused;
    bool public claimPaused;

    /**
     * @notice Deploys the contract and saves the HelloToken contract address
     *  @dev `msg.sender` is assigned to the owner, pay attention if this contract is deployed via another contract
     *  @param _helloToken The address of HelloToken
     */
    constructor(address _helloToken) {
        HELLO_TOKEN = IERC20(_helloToken);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  external                                  */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice Bridge HelloToken to another chain. HelloToken will be transferred to this contract.
     * @notice Ensure approvals for HelloToken has been set and the destination chain is supported.
     * @param amount Amount of HelloToken to bridge to another chain
     * @param chainId The chain ID of the destination chain
     * @dev Reverts if the destination chain is not supported
     */
    function sendToChain(uint256 amount, uint256 chainId) external {
        if (depositPaused) _revert(Paused.selector);

        // check chain
        if (!supportedChains[chainId]) _revert(CannotBridgeToUnsupportedChain.selector);

        // update state
        uint256 _currentDepsosit = store.totalCrossChainDeposits(msg.sender, chainId);
        store.setTotalCrossChainDeposits(msg.sender, chainId, _currentDepsosit + amount);

        // transfer tokens
        HELLO_TOKEN.transferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount, chainId);
    }

    /**
     * @notice Claims tokens deposited in the source chain. A signature is required.
     * @notice HelloToken will be transferred from this account to the caller.
     * @param totalDepositedOnOtherChain The total amount you have deposited in the source chain
     * @param otherChainId The chain ID of the source chain
     * @param signature The signature signed by `withdrawSigner`
     * @dev Reverts if there's no amount to claim.
     * @dev Reverts if the signature is invalid
     * @dev Assumptions:
     *     - `otherChainId` is supported, a user would not have been able to deposit if the path from `otherChainId` to this chain is not supported
     *     - `totalDepositedOnOtherChain` is checked on chain with ID `otherChainId` before a signature is generated for this transaction
     */
    function claimFromChain(
        uint256 totalDepositedOnOtherChain,
        uint256 otherChainId,
        bytes memory signature,
        bytes memory signature2
    ) external {
        if (claimPaused) _revert(Paused.selector);

        // note: this can never undeflow as the user would not have been able to withdraw if they had no balance
        uint256 amountToWithdraw =
            totalDepositedOnOtherChain - store.totalCrossChainWithdrawals(msg.sender, otherChainId);

        // check amount
        if (amountToWithdraw == 0) _revert(NoAmountToWithdraw.selector);

        // check signature
        bytes32 hash = keccak256(
            abi.encodePacked(msg.sender, totalDepositedOnOtherChain, otherChainId, block.chainid, address(this))
        );

        if (hash.toEthSignedMessageHash().recover(signature) != withdrawSigner1) {
            _revert(SignerNotWithdrawSigner.selector);
        }

        if (hash.toEthSignedMessageHash().recover(signature2) != withdrawSigner2) {
            _revert(SignerNotWithdrawSigner.selector);
        }

        // update state
        store.setTotalCrossChainWithdrawals(msg.sender, otherChainId, totalDepositedOnOtherChain);

        // transfer tokens
        HELLO_TOKEN.transfer(msg.sender, amountToWithdraw);

        emit Claim(msg.sender, totalDepositedOnOtherChain, otherChainId);
    }

    /* -------------------------------------------------------------------------- */
    /*                                   owners                                   */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice Owner only - Updates the address of the withdrawal signer
     * @param _withdrawSigner Address of the withdrawal signer
     */
    function setWithdrawSigner(address _withdrawSigner) external onlyOwner {
        // check
        if (_withdrawSigner == address(0)) {
            _revert(ZeroAddress.selector);
        }

        // set
        withdrawSigner1 = _withdrawSigner;

        // emit
        emit WithdrawSigner1Changed(_withdrawSigner);
    }

    function setWithdrawSigner2(address _withdrawSigner2) external onlyOwner {
        // check
        if (_withdrawSigner2 == address(0)) {
            _revert(ZeroAddress.selector);
        }

        // set
        withdrawSigner2 = _withdrawSigner2;

        // emit
        emit WithdrawSigner2Changed(_withdrawSigner2);
    }

    /**
     * @notice Owner only - Updates a supported destination chain
     * @param chainId Chain ID of a destination chain
     * @param isSupported Whether the destination chain is supported
     */
    function setSupportedChain(uint256 chainId, bool isSupported) external onlyOwner {
        _setSupportedChain(chainId, isSupported);

        emit SupportedChainChanged(chainId, isSupported);
    }

    /**
     * @notice Owner only - Batch update supported destination chains
     * @param chainIds Chain IDs of the destination chains
     * @param isSupported Whether the destination chains are supported
     */
    function setSupportedChains(uint256[] calldata chainIds, bool isSupported) external onlyOwner {
        for (uint256 i; i < chainIds.length;) {
            _setSupportedChain(chainIds[i], isSupported);
            unchecked {
                ++i;
            }
        }

        emit SupportedChainsChanged(chainIds, isSupported);
    }

    /**
     * @notice Pause / unpause deposit & claim
     * @param depositPaused_ Whether to pause deposit
     * @param depositPaused_ Whether to pause claim
     */
    function setPaused(bool depositPaused_, bool claimPaused_) external onlyOwner {
        depositPaused = depositPaused_;
        claimPaused = claimPaused_;

        emit PausedChanged(depositPaused_, claimPaused_);
    }

    function setBridgeStore(address a_) external onlyOwner {
        // check
        if (a_ == address(0)) {
            _revert(ZeroAddress.selector);
        }

        // set
        store = HelloBridgeStore(a_);

        // emit
        emit BridgeStoreChanged(a_);
    }

    /**
     * @notice Migrates the bridge contract to another. Tokens in this contract will be transferred to the new contract.
     * @dev The new bridge contract should use the data stored in `store`.
     * @param bridgeAddress Address of the new contract
     */
    function migrateBridge(address bridgeAddress) external onlyOwner {
        // check zero
        if (bridgeAddress == address(0)) {
            _revert(ZeroAddress.selector);
        }

        // check paused
        if (!depositPaused || !claimPaused) {
            _revert(NotPaused.selector);
        }

        HELLO_TOKEN.transfer(bridgeAddress, HELLO_TOKEN.balanceOf(address(this)));
    }

    /* -------------------------------------------------------------------------- */
    /*                                  internal                                  */
    /* -------------------------------------------------------------------------- */
    function _setSupportedChain(uint256 chainId, bool isSupported) internal {
        supportedChains[chainId] = isSupported;
    }

    function _revert(bytes4 selector) internal pure {
        assembly {
            mstore(0x0, selector)
            revert(0x0, 0x04)
        }
    }
}
