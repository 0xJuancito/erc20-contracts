// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { OFT } from "@layerzerolabs/solidity-examples/contracts/token/oft/OFT.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";

import { ERC2771Recipient } from "../metatx/ERC2771Recipient.sol";
import { EchelonGateways } from "./EchelonGateways.sol";
import { IPrimeToken } from "./interfaces/IPrimeToken.sol";

contract PrimeToken is IPrimeToken, OFT, ERC2771Recipient, ReentrancyGuard {
    /**
     * @notice EchelonGateway record stores the details of an EchelonGateways contract
     */
    struct EchelonGateway {
        address nativeTokenDestinationAddress;
        address primeDestinationAddress;
        EchelonGateways invokeEchelonHandler;
    }

    /**
     * @notice a record of all EchelonGateways
     */
    mapping(address => EchelonGateway) public echelonGateways;

    constructor(
        address _lzEndpoint,
        address _forwarder
    ) OFT("Prime", "PRIME", _lzEndpoint) ERC2771Recipient(_forwarder) {}

    /**
     * @notice Updated trusted forwarder address.
     * @param _forwarder New trusted forwarder address.
     */
    function setTrustedForwarder(address _forwarder) external onlyOwner {
        _setTrustedForwarder(_forwarder);
        emit TrustedForwarderSet(_forwarder);
    }

    /**
     * @notice Allow the caller to send PRIME to the Echelon Ecosystem of smart
     *         contracts. PRIME are collected to the destination address,
     *         handler is invoked to trigger downstream logic and events
     * @dev We do a transfer call as opposed to a transferFrom because normally when you call
     *      transferFrom from another contract, _msgSender() would be that contract itself, but since
     *      we are calling transferFrom from within the erc20 itself, the _msgSender() returns the caller
     *      From the following two lines, it will error out because 'from == echeloner'
     *      address echeloner = _msgSender();
     *      _echelonAllowance(from, echeloner, amount);
     *
     * @param _handlerAddress The address of the deployed and registered
     *        EchelonGateways contract
     * @param _id An id passed by the caller to represent any arbitrary and
     *        potentially off-chain event id
     * @param _primeValue The amount of PRIME that was sent to the
     *        invokeEchelon function (and was collected to _destination)
     * @param _data Catch-all param to allow the caller to pass additional
     *        data to the handler
     */
    function invokeEchelon(
        address _handlerAddress,
        uint256 _id,
        uint256 _primeValue,
        bytes memory _data
    ) public payable nonReentrant {
        require(
            msg.value + _primeValue > 0,
            "PrimeTokenOFT: No msg.value or PRIME"
        );
        require(
            echelonGateways[_handlerAddress].primeDestinationAddress !=
                address(0),
            "PrimeTokenOFT: not a handler"
        );

        EchelonGateway memory gateway = echelonGateways[_handlerAddress];

        if (msg.value > 0) {
            (bool sent, ) = gateway.nativeTokenDestinationAddress.call{
                value: msg.value
            }("");
            require(sent, "Failed to send native token");
        }

        // Transfer uses _msgSender() PRIME from user, not from the OFT contract itself
        if (_primeValue > 0) {
            transfer(gateway.primeDestinationAddress, _primeValue);
        }

        // invoke the handler function with all transaction data
        EchelonGateways(_handlerAddress).handleInvokeEchelon(
            _msgSender(),
            gateway.nativeTokenDestinationAddress,
            gateway.primeDestinationAddress,
            _id,
            msg.value,
            _primeValue,
            _data
        );

        emit EchelonInvoked(
            _msgSender(),
            gateway.nativeTokenDestinationAddress,
            gateway.primeDestinationAddress,
            _id,
            msg.value,
            _primeValue,
            _data
        );
    }

    /**
     * @notice Allow an address with ADMIN_ROLE to add a handler contract for invokeEchelon
     * @dev additional handler contracts will be added to support new use cases, existing handler contracts can never be
     *      deleted nor replaced
     * @param _contractAddress - The address of the new invokeEchelon handler contract to be registered
     * @param _nativeTokenDestinationAddress - The address to which MATIC is collected
     * @param _primeDestinationAddress - The address to which PRIME is collected
     */
    function addEchelonHandlerContract(
        address _contractAddress,
        address _nativeTokenDestinationAddress,
        address _primeDestinationAddress
    ) public onlyOwner {
        require(
            _nativeTokenDestinationAddress != address(0) &&
                _primeDestinationAddress != address(0),
            "Destination addresses cannot be 0x0"
        );
        require(
            echelonGateways[_contractAddress].primeDestinationAddress ==
                address(0),
            "Can't overwrite existing gateway"
        );
        echelonGateways[_contractAddress] = EchelonGateway({
            nativeTokenDestinationAddress: _nativeTokenDestinationAddress,
            primeDestinationAddress: _primeDestinationAddress,
            invokeEchelonHandler: EchelonGateways(_contractAddress)
        });
        emit EchelonGatewayRegistered(
            _contractAddress,
            _nativeTokenDestinationAddress,
            _primeDestinationAddress
        );
    }

    /**
     * @notice Calls internal function _send
     *         For isCreditTo=False
     *         Use V2 for adapterParams to pass airdrop value that will be use on destination to pay fees for OFT callback message
     *         For isCreditTo=True
     *         Use V1 for adapterParams to do simple bridge
     * @param _from The address that will have its tokens burned when bridging
     * @param _dstChainId The destination chain identifier
     * @param _amount Amount of tokens to bridge
     * @param _refundAddress If the source transaction is cheaper than the amount of value passed, refund the additional amount to this address
     * @param _zroPaymentAddress The address of the ZRO token holder who would pay for the transaction
     * @param _adapterParams parameters for custom functionality. e.g. receive airdropped native gas from the relayer on destination
     */
    function send(
        address _from,
        uint16 _dstChainId,
        uint256 _amount,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes memory _adapterParams
    ) public payable virtual {
        _send(
            _from,
            _dstChainId,
            abi.encodePacked(_from),
            _amount,
            _refundAddress,
            _zroPaymentAddress,
            _adapterParams
        );
    }

    /**
     *  @notice Overridden _msgSender to handle ERC2771
     */
    function _msgSender()
        internal
        view
        virtual
        override(Context, ERC2771Recipient)
        returns (address ret)
    {
        ret = ERC2771Recipient._msgSender();
    }

    /**
     *  @notice Overridden _msgData to handle ERC2771
     */
    function _msgData()
        internal
        view
        virtual
        override(Context, ERC2771Recipient)
        returns (bytes calldata)
    {
        return ERC2771Recipient._msgData();
    }
}
