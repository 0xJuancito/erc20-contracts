// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.17;

import "./ISmartCoin.sol";
import "../libraries/EncodingUtils.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./WhitelistUpgradeable.sol";
import "./SmartCoinDataLayout.sol";

/**
 * @dev Used when trying to validate an unknown transfer request
 */
error TransferRequestNotFound();
/**
 * @dev Used when trying to validate an already validated transfer request
 */
error InvalidTransferRequestStatus();
error SpenderLockedForApproval();
/**
 * @dev Used when "available" balance is insufficient
 */
error InsufficientBalance(uint256 current, uint256 required);

/**
 * @dev The `SmartCoin` contract is basically an ERC20 with a few specifics
 * It uses the UUPS upgrade mechanism
 * It has a set of operators with specific rights :
 * - the registrar operator :
 *      - manages the whitelist of authorized users
 *      - reviews(and either validates or rejects) transfers of tokens back to the registrar or the operations address
 *      - names the operators for next implementation contract upgrade (WhitelistUpgradeable.nameNewOperators)
 *      - authorises upgrade to next implementation contract (WhitelistUpgradeable.authorizeImplementation)
 * - the operations operator is a special address used when token owners want to 'cash out' of the SmartCoin
 * (i.e. sell their tokens to the issuer in exchange for cash) :
 *      - it is not possible to use the operations operator's address as spender or destination of a transferFrom
 *      - transfers to the operations address have to be reviewed by the registrar operator before being performed.
 * - the technical operator :
 *      - only the technical operator can launch a (previously authorised) upgrade of the implementation contract (upgradeTo/upgradeToAndCall)
 */
contract SmartCoin is
    SmartCoinDataLayout,
    WhitelistUpgradeable,
    ERC20Upgradeable,
    UUPSUpgradeable,
    ISmartCoin
{
    /**
     * @dev Performs balance checks based on the "available" balance instead of total balance
     * The "available" balance excludes tokens currently engaged in a transfer request,
     * which is a two-step transfer back to the registrar operator or the operations operator
     * (initiated with the transfer() method)
     */
    modifier onlyWhenBalanceAvailable(address _from, uint256 _value) {
        uint256 availableBalance = _availableBalance(_from);
        if (_value > availableBalance)
            revert InsufficientBalance({
                current: availableBalance,
                required: _value
            });
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address _registrar,
        address _operations,
        address _technical
    )
        onlyNotZeroAddress(_registrar)
        onlyNotZeroAddress(_operations)
        onlyNotZeroAddress(_technical)
        OnlyWhenOperatorsHaveDifferentAddress(
            _registrar,
            _operations,
            _technical
        )
        WhitelistUpgradeable(_registrar, _operations, _technical)
    {
        // https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable#potentially-unsafe-operations
        // https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable#initializing_the_implementation_contract
        _disableInitializers();
    }

    /**
     * @dev Recalls a `amount` amount of tokens from `from` address
     * The tokens are transferred back to the registrar operator
     *
     * NB: This method is reserved to the registrar operator.
     */
    function recall(
        address _from,
        uint256 _amount
    )
        external
        override
        onlyRegistrar
        onlyWhenBalanceAvailable(_from, _amount)
        returns (bool)
    {
        super._transfer(_from, registrar, _amount);
        return true;
    }

    /**
     * @dev Burns a `amount` amount of tokens from the caller.
     * NB: only the registrar operator is allowed to burn their tokens
     */
    function burn(
        uint256 _amount
    )
        external
        override
        onlyRegistrar
        onlyWhenBalanceAvailable(registrar, _amount)
        returns (bool)
    {
        super._burn(registrar, _amount);
        return true;
    }

    /**
     * @dev Mints a `amount` amount of tokens on `to` address
     * NB: only the registrar operator is allowed to mint new tokens
     * NB: the `_to` address has to be whitelisted
     */
    function mint(
        address _to,
        uint256 _amount
    ) external override onlyRegistrar onlyWhitelisted(_to) returns (bool) {
        super._mint(_to, _amount);
        return true;
    }

    function upgradeTo(
        address _newImplementation
    )
        external
        virtual
        override
        onlyProxy
        consumeAuthorizeImplementation(_newImplementation)
    {
        _authorizeUpgrade(_newImplementation);
        _upgradeToAndCallUUPS(_newImplementation, new bytes(0), false);
        _resetNewOperators();
    }

    function upgradeToAndCall(
        address _newImplementation,
        bytes memory data
    )
        external
        payable
        virtual
        override
        onlyProxy
        consumeAuthorizeImplementation(_newImplementation)
    {
        _authorizeUpgrade(_newImplementation);
        _upgradeToAndCallUUPS(_newImplementation, data, true);
        _resetNewOperators();
    }

    /**
     * @dev Actually performs the transfer request corresponding to the given `transferHash`
     * NB: only for transfers whose destination is either the registrar operator's address or the operations operator's
     * Called by the registrar operator
     */
    function validateTransfer(
        bytes32 transferHash
    ) external onlyRegistrar returns (bool) {
        TransferRequest memory _transferRequest = _transfers[transferHash];

        if (_transferRequest.status == TransferStatus.Undefined) {
            revert TransferRequestNotFound();
        }

        if (_transferRequest.status != TransferStatus.Created) {
            revert InvalidTransferRequestStatus();
        }

        _transfers[transferHash].status = TransferStatus.Validated;

        unchecked {
            _engagedAmount[_transferRequest.from] -= _transferRequest.value;
        }

        _safeTransfer(
            _transferRequest.from,
            _transferRequest.to,
            _transferRequest.value
        );

        emit TransferValidated(transferHash);
        return true;
    }

    /**
     * @dev Rejects(and thus, actually cancels) the transfer request corresponding to the given `transferHash`
     * NB: only for transfers whose destination is either the registrar operator's address or the operations operator's
     * Called by the registrar operator
     */
    function rejectTransfer(
        bytes32 transferHash
    ) external onlyRegistrar returns (bool) {
        TransferRequest memory transferRequest = _transfers[transferHash];

        if (transferRequest.status == TransferStatus.Undefined) {
            revert TransferRequestNotFound();
        }

        if (transferRequest.status != TransferStatus.Created) {
            revert InvalidTransferRequestStatus();
        }
        unchecked {
            _engagedAmount[transferRequest.from] -= transferRequest.value;
        }
        _transfers[transferHash].status = TransferStatus.Rejected;

        emit TransferRejected(transferHash);

        return true;
    }

    /**
     * @dev Returns the contract's operators' addresses
     */
    function getOperators() external view returns (address, address, address) {
        return (registrar, operations, technical);
    }

    /**
     * @dev Returns the version number of this contract
     */
    function version() external pure virtual returns (string memory) {
        return "V1";
    }

    /**
     * @dev UUPS initializer that initializes the token's name and symbol
     */
    function initialize(
        string memory _name,
        string memory _symbol
    ) public initializer {
        __ERC20_init(_name, _symbol);
        __Whitelist_init();
        __UUPSUpgradeable_init();
    }

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     * NB: both the owner(msg.sender) and the spender have to be whitelisted addresses
     * NB: Will fail if the spender is either the registar operator or the operations operator
     */
    function approve(
        address _spender,
        uint256 _value
    )
        public
        override(ERC20Upgradeable, ISmartCoin)
        onlyWhitelisted(_msgSender())
        onlyWhitelisted(_spender)
        forbiddenForRegistrar(_spender)
        forbiddenForOperations(_spender)
        returns (bool)
    {
        super._approve(_msgSender(), _spender, _value);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `requestedDecrease`.
     * - `spender` and msg.sender have to be whitelisted addresses
     * - `spender` cannot be either the registar operator or the operations operator
     *
     * NOTE: Although this function is designed to avoid double spending with {approval},
     * it can still be frontrunned, preventing any attempt of allowance reduction.
     */
    function decreaseAllowance(
        address _spender,
        uint256 _subtractedValue
    )
        public
        override(ERC20Upgradeable, ISmartCoin)
        onlyWhitelisted(_spender)
        onlyWhitelisted(_msgSender())
        forbiddenForRegistrar(_spender)
        forbiddenForOperations(_spender)
        returns (bool)
    {
        return super.decreaseAllowance(_spender, _subtractedValue);
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` and msg.sender have to be whitelisted addresses
     * - `spender` cannot be either the registar operator or the operations operator
     */
    function increaseAllowance(
        address _spender,
        uint256 _addedValue
    )
        public
        override(ERC20Upgradeable, ISmartCoin)
        onlyWhitelisted(_spender)
        onlyWhitelisted(_msgSender())
        forbiddenForRegistrar(_spender)
        forbiddenForOperations(_spender)
        returns (bool)
    {
        return super.increaseAllowance(_spender, _addedValue);
    }

    /**
     * @dev Same semantic as ERC20's transferFrom function(no validation needed)
     * NB: the owner(_from),the spender(msg.sender) and the destination have to be whitelisted addresses
     * NB: Will fail if the destination is either the registar operator or the operations operator
     */
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    )
        public
        override(ERC20Upgradeable, ISmartCoin)
        onlyWhitelisted(_msgSender())
        onlyWhitelisted(_from)
        onlyWhitelisted(_to)
        forbiddenForRegistrar(_to)
        forbiddenForOperations(_to)
        onlyWhenBalanceAvailable(_from, _value)
        returns (bool)
    {
        return super.transferFrom(_from, _to, _value);
    }

    /**
     * @dev Same semantic as ERC20's transfer function although there are 2 cases :
     * 1- if the destination address is neither the registar operator's nor the operations operator's,
     * then the transfer will occur right away
     * 2 - if the destination is either the registrar operator's or the operations operator's
     * then the transfer will only actually occur once validated by the registrar operator
     * using the validateTransfer method
     *
     * NB: both the source(msg.sender) and the destination have to be whitelisted addresses
     */
    function transfer(
        address _to,
        uint256 _value
    )
        public
        override(ISmartCoin, ERC20Upgradeable)
        onlyWhitelisted(_msgSender())
        onlyWhitelisted(_to)
        onlyWhenBalanceAvailable(_msgSender(), _value)
        returns (bool)
    {
        if (_to != registrar && _to != operations) {
            _safeTransfer(_msgSender(), _to, _value);
        } else {
            _initiateTransferRequest(_msgSender(), _to, _value);
        }

        return true;
    }

    /**
     * @dev Returns the balance of `addr` account.
     * NB: The returned balance is the "available" balance, which excludes tokens engaged in a transfer request
     * (i.e. a transfer back to the registrar operator or the operations operator)
     */
    function balanceOf(
        address _addr
    ) public view override(ERC20Upgradeable, ISmartCoin) returns (uint256) {
        return _availableBalance(_addr);
    }

    /**
     * @dev Returns current amount engaged in transfer requests for `addr` account
     */
    function engagedAmount(address _addr) public view returns (uint256) {
        return _engagedAmount[_addr];
    }

    /**
     * @dev Internal method initiating a two-step transfer request.
     * and emits a corresponding `TransferRequested` event
     * Used when the destination of the transfer is either the registrar operator or the operations operator.
     *
     * NB : to comply with the ERC20 standard, this method emits a Transfer event with 0 value
     * another Transfer event with the correct value will occur if the transfer request is validated through a call to validateTransfer()
     */
    function _initiateTransferRequest(
        address _from,
        address _to,
        uint256 _value
    ) internal {
        unchecked {
            _engagedAmount[_from] += _value; // No overflow since balance >= engagedAmount
        }

        bytes32 transferHash = EncodingUtils.encodeRequest(
            _from,
            _to,
            _value,
            _requestCounter
        );

        _transfers[transferHash] = TransferRequest(
            _from,
            _to,
            _value,
            TransferStatus.Created
        );

        _requestCounter += 1;

        emit Transfer(_from, _to, 0); // Required by https://eips.ethereum.org/EIPS/eip-20#transfer
        emit TransferRequested(transferHash, _from, _to, _value);
    }

    function _safeTransfer(
        address _from,
        address _to,
        uint256 _value
    ) internal onlyWhitelisted(_from) onlyWhitelisted(_to) {
        super._transfer(_from, _to, _value);
    }

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyTechnical {}

    /**
     * @dev Internal method that computes the available(i.e. not engaged) balance
     */
    function _availableBalance(address _addr) internal view returns (uint256) {
        unchecked {
            return super.balanceOf(_addr) - _engagedAmount[_addr]; // No overflow since balance >= engagedAmount
        }
    }
}
