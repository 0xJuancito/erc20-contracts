// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "./interfaces/IChildToken.sol";
import "./utils/Claimable.sol";
import "./utils/ImmutableOwnable.sol";

/**
 * @title PZkpToken
 * @notice $ZKP token on Polygon
 * @dev This contract is supposed to run on Polygon and be "mapped" to
 * the ZKPToken contract on the mainnet via the Polygon PoS bridge
 */
contract PZkpToken is ERC20Permit, ImmutableOwnable, Claimable, IChildToken {
    string private constant _name = "$ZKP Token";
    string private constant _symbol = "$ZKP";

    // solhint-disable-next-line var-name-mixedcase
    bytes32 private constant META_TRANSACTION_TYPEHASH =
        keccak256(
            "MetaTransaction(uint256 nonce,address from,bytes functionSignature)"
        );

    event MetaTransactionExecuted(
        address userAddress,
        address relayerAddress,
        bytes functionSignature
    );

    /// @notice Account authorized to mint tokens against deposits on the mainnet
    /// @dev Supposed to be the `ChildChainManager` contract (by the Polygon team)
    address public minter;

    modifier onlyMinter() {
        require(msg.sender == minter, "ZKP: unauthorized");
        _;
    }

    constructor(address owner)
        ERC20(_name, _symbol)
        ERC20Permit(_name)
        ImmutableOwnable(owner)
    {
        // Owner is supposed to transfer the minter role to the ChildChainManager
        // by a separate `setMinter` call (thus "enabling" bridging/deposits)
        _setMinter(owner);
    }

    /**
     * @notice Called when token is deposited on the mainnet
     * @dev It handles deposit by minting the required amount for a user
     * SHOULD be callable only by the ChildChainManager
     * @param user User address for whom deposit is being done
     * @param depositData Abi encoded amount
     */
    function deposit(address user, bytes calldata depositData)
        external
        override
        onlyMinter
    {
        uint256 amount = abi.decode(depositData, (uint256));
        _mint(user, amount);
    }

    /**
     * @notice Called when user wants to withdraw tokens back to the mainnet
     * @dev It burns user's tokens which will be verified when exiting on the mainnet
     * @param amount Amount of tokens to withdraw
     */
    function withdraw(uint256 amount) external {
        _burn(_msgSender(), amount);
    }

    // batch functions
    function batchTransfer(
        address[] calldata _recipients,
        uint256[] calldata _values
    ) external returns (bool) {
        _throwLengthMismatch(_recipients.length, _values.length);

        for (uint256 i = 0; i < _recipients.length; i++) {
            require(
                transfer(_recipients[i], _values[i]),
                "ZKP: unable to transfer"
            );
        }

        return true;
    }

    function batchTransferFrom(
        address _from,
        address[] calldata _recipients,
        uint256[] calldata _values
    ) external returns (bool) {
        _throwLengthMismatch(_recipients.length, _values.length);

        for (uint256 i = 0; i < _recipients.length; i++) {
            require(
                transferFrom(_from, _recipients[i], _values[i]),
                "ZKP: unable to transfer"
            );
        }

        return true;
    }

    function batchIncreaseAllowance(
        address[] calldata _spenders,
        uint256[] calldata _addedValues
    ) external returns (bool) {
        _throwLengthMismatch(_spenders.length, _addedValues.length);

        for (uint256 i = 0; i < _addedValues.length; i++) {
            require(
                increaseAllowance(_spenders[i], _addedValues[i]),
                "ZKP: unable to increase"
            );
        }

        return true;
    }

    function batchDecreaseAllowance(
        address[] calldata _spenders,
        uint256[] calldata _subtractedValues
    ) external returns (bool) {
        _throwLengthMismatch(_spenders.length, _subtractedValues.length);

        for (uint256 i = 0; i < _subtractedValues.length; i++) {
            require(
                decreaseAllowance(_spenders[i], _subtractedValues[i]),
                "ZKP: unable to decrease"
            );
        }

        return true;
    }

    /// @notice It executes "Native meta transactions"
    /// @dev Any function on this contract may be called via a relayer on behalf
    /// of a user, providing a valid ECDSA signature of the user and properly
    /// formed call data submitted
    function executeMetaTransaction(
        address userAddress,
        bytes memory functionSignature,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) public payable returns (bytes memory) {
        bytes32 structHash = keccak256(
            abi.encode(
                META_TRANSACTION_TYPEHASH,
                _useNonce(userAddress),
                userAddress,
                keccak256(functionSignature)
            )
        );
        bytes32 hash = _hashTypedDataV4(structHash);

        address signer = ECDSA.recover(hash, v, r, s);
        require(signer == userAddress, "ZKP: invalid signature");

        emit MetaTransactionExecuted(
            userAddress,
            msg.sender,
            functionSignature
        );

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returnData) = address(this).call(
            // Append userAddress at the end to extract it from calling context
            abi.encodePacked(functionSignature, userAddress)
        );
        require(success, "ZKP: Meta tx call failed");

        return returnData;
    }

    /// @notice Withdraws accidentally sent token from this contract
    /// @dev Owner may call only
    function claimErc20(
        address claimedToken,
        address to,
        uint256 amount
    ) external onlyOwner nonReentrant {
        _claimErc20(claimedToken, to, amount);
    }

    /// @notice Sets the minter role to given address
    /// @dev Account with the minter role may call only
    function setMinter(address _minter) public onlyMinter {
        _setMinter(_minter);
    }

    /// Internal and private functions follow

    // To support meta transactions, this to be used instead of msg.sender directly
    function _msgSender() internal view override returns (address sender) {
        if (msg.sender == address(this)) {
            bytes memory array = msg.data;
            uint256 index = msg.data.length;
            // solhint-disable-next-line no-inline-assembly
            assembly {
                // Load the address in lower 20 bytes of the 32 bytes word.
                sender := and(
                    mload(add(array, index)),
                    0xffffffffffffffffffffffffffffffffffffffff
                )
            }
        } else {
            sender = msg.sender;
        }
        return sender;
    }

    function _setMinter(address _minter) internal {
        require(_minter != address(0), "ZKP: zero minter address");
        minter = _minter;
    }

    function _throwLengthMismatch(uint256 l1, uint256 l2) private pure {
        require(l1 == l2, "ZKP: invalid input");
    }
}
