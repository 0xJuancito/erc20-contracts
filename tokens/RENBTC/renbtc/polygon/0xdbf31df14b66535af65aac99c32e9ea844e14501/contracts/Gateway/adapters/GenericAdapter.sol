pragma solidity ^0.5.17;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC777/IERC777Recipient.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC777/IERC777.sol";

import "../interfaces/IGateway.sol";
import "../interfaces/IGatewayRegistry.sol";
import "./IERC1155/IERC1155.sol";
import "./IERC1155/IERC1155Receiver.sol";

contract GenericAdapter is
    Ownable,
    IERC721Receiver,
    IERC777Recipient,
    IERC1155Receiver
{
    using SafeMath for uint256;

    IGatewayRegistry public registry;

    constructor(IGatewayRegistry _registry) public {
        Ownable.initialize(msg.sender);
        registry = _registry;
    }

    function directMint(
        // Payload
        string calldata _symbol,
        address _account,
        uint256 _submitterFee,
        // Required
        uint256 _amount,
        bytes32 _nHash,
        bytes calldata _sig
    ) external {
        // Allow the account to submit without a fee.
        if (_account == msg.sender) {
            _submitterFee = 0;
        }

        // Calculate the payload hash for the first six parameters.
        bytes32 payloadHash =
            keccak256(abi.encode(_symbol, _account, _submitterFee));

        // Call `mint` on the Gateway contract.
        uint256 amount =
            registry.getGatewayBySymbol(_symbol).mint(
                payloadHash,
                _amount,
                _nHash,
                _sig
            );

        IERC20 token = registry.getTokenBySymbol(_symbol);
        token.transfer(_account, amount.sub(_submitterFee));

        // Pay fee as last step.
        if (_submitterFee > 0) {
            token.transfer(msg.sender, _submitterFee);
        }
    }

    // Track the caller in case there's ERC721
    address currentAccount;

    function genericCall(
        // Payload
        string calldata _symbol,
        address _account,
        address _contract,
        bytes calldata _contractParams,
        IERC20[] calldata _refundTokens,
        uint256 _submitterFee,
        // Required
        uint256 _amount,
        bytes32 _nHash,
        bytes calldata _sig
    ) external {
        address previousAccount = currentAccount;
        currentAccount = _account;

        // Split up to work around stack-too-deep errors.
        // The function body is spread across the following three functions:
        // * _genericCallInner,
        // * _returnReceivedTokens,
        // * _mintAndCall
        _genericCallInner(
            _symbol,
            _account,
            _contract,
            _contractParams,
            _refundTokens,
            _submitterFee,
            _amount,
            _nHash,
            _sig
        );

        // Reset `currentAccount`.
        currentAccount = previousAccount;
    }

    function _genericCallInner(
        // Payload
        string memory _symbol,
        address _account,
        address _contract,
        bytes memory _contractParams,
        IERC20[] memory _refundTokens,
        uint256 _submitterFee,
        // Required
        uint256 _amount,
        bytes32 _nHash,
        bytes memory _sig
    ) internal {
        // Allow the account to submit without a fee.
        if (_account == msg.sender) {
            _submitterFee = 0;
        }

        // Calculate the payload hash for the first six parameters.
        bytes32 payloadHash =
            keccak256(
                abi.encode(
                    _symbol,
                    _account,
                    _contract,
                    _contractParams,
                    _refundTokens,
                    _submitterFee
                )
            );

        _mintAndCall(
            payloadHash,
            _symbol,
            _contract,
            _contractParams,
            _submitterFee,
            _amount,
            _nHash,
            _sig
        );

        _returnReceivedTokens(_symbol, _refundTokens, _submitterFee);
    }

    function _returnReceivedTokens(
        string memory _symbol,
        IERC20[] memory _refundTokens,
        uint256 _submitterFee
    ) internal {
        IERC20 token = registry.getTokenBySymbol(_symbol);

        // The user must specify which tokens may potentially be recieved during
        // the contract call. Note that if one of the matched refund tokens
        // match `token` and a fee is paid out later on, the transaction will
        // revert.
        for (uint256 i = 0; i < _refundTokens.length; i++) {
            IERC20 refundToken = IERC20(_refundTokens[i]);
            uint256 refundBalance = refundToken.balanceOf(address(this));
            if (refundBalance > 0) {
                refundToken.transfer(currentAccount, refundBalance);
            }
        }

        // Return any remaining `token` balance.
        uint256 tokenBalance = token.balanceOf(address(this));
        if (tokenBalance > _submitterFee) {
            token.transfer(currentAccount, tokenBalance.sub(_submitterFee));
        }

        // Remain any remaining ETH balance.
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            (bool success, ) = currentAccount.call.value(ethBalance)("");
            require(success);
        }

        // Pay fee as last step.
        if (_submitterFee > 0) {
            token.transfer(msg.sender, _submitterFee);
        }
    }

    function _mintAndCall(
        bytes32 payloadHash,
        string memory _symbol,
        address _contract,
        bytes memory _contractParams,
        uint256 _submitterFee,
        uint256 _amount,
        bytes32 _nHash,
        bytes memory _sig
    ) internal {
        // Call `mint` on the Gateway contract.
        uint256 amount =
            registry.getGatewayBySymbol(_symbol).mint(
                payloadHash,
                _amount,
                _nHash,
                _sig
            );

        IERC20 token = registry.getTokenBySymbol(_symbol);

        // Approval the amount excluding the fee.
        uint256 oldApproval = token.allowance(address(this), _contract);
        token.approve(_contract, oldApproval.add(amount.sub(_submitterFee)));

        // Call contract with the contract parameters.
        arbitraryCall(_contract, _contractParams);

        // Revoke approval.
        token.approve(_contract, oldApproval);
    }

    function onERC721Received(
        address,
        address,
        uint256 tokenId,
        bytes memory data
    ) public returns (bytes4) {
        // Forward on to current account.
        IERC721(msg.sender).safeTransferFrom(
            address(this),
            currentAccount,
            tokenId,
            data
        );
        return this.onERC721Received.selector;
    }

    function tokensReceived(
        address,
        address,
        address,
        uint256 amount,
        bytes memory userData,
        bytes memory
    ) public {
        IERC777(msg.sender).send(currentAccount, amount, userData);
    }

    function onERC1155Received(
        address,
        address,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4) {
        IERC1155(msg.sender).safeTransferFrom(
            address(this),
            currentAccount,
            id,
            value,
            data
        );
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4) {
        IERC1155(msg.sender).safeBatchTransferFrom(
            address(this),
            currentAccount,
            ids,
            values,
            data
        );
        return this.onERC1155BatchReceived.selector;
    }

    // Allow the owner to recover tokens and collectibles stuck in the contract.
    // This contract is not meant to hold funds.
    function _recover(address _contract, bytes calldata _contractParams)
        external
        onlyOwner
    {
        arbitraryCall(_contract, _contractParams);
    }

    function arbitraryCall(address _contract, bytes memory _contractParams)
        internal
    {
        (bool success, bytes memory result) = _contract.call(_contractParams);
        if (!success) {
            // Check if the call result was too short to be a revert reason.
            if (result.length < 68) {
                revert(
                    "GenericAdapter: contract call failed without revert reason"
                );
            }
            // Return the call's revert reason.
            assembly {
                let ptr := mload(0x40)
                let size := returndatasize
                returndatacopy(ptr, 0, size)
                revert(ptr, size)
            }
        }
    }
}
