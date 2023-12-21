pragma solidity 0.8.17;

import "./Whitelist.sol";
import "./ISmartCoin.sol";
import "../openzepplin/ERC20.sol";
import "../libraries/EncodingUtils.sol";

contract SmartCoin is Whitelist, ERC20, ISmartCoin {
    mapping(bytes32 => TransferRequest) private _transfers;
    uint256 private _requestCounter;

    mapping(address => mapping(address => bool)) private _hasOngoingApprove;
    mapping(bytes32 => ApproveRequest) private _approves;

    mapping(address => uint256) private _engagedAmount; // _engagedAmount amount in transfer or approve

    constructor(address registrar)
        ERC20("EUR Coinvertible", "EURCV")
        Whitelist(registrar)
    {}

    function validateTransfer(bytes32 transferHash)
        external
        onlyRegistrar
        returns (bool)
    {
        TransferRequest memory _transferRequest = _transfers[transferHash];
        if (_transferRequest.isTransferFrom) {
            if(!whitelist[_transferRequest.spender]){
                revert("Whitelist: address must be whitelisted");
            }
        }
        require(
            _transferRequest.status != TransferStatus.Undefined,
            "SmartCoin: transferHash does not exist"
        );
        require(
            _transferRequest.status == TransferStatus.Created,
            "SmartCoin: Invalid transfer status"
        );
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

    function _safeApprove(
        address _from,
        address _to,
        uint256 _value
    ) internal onlyWhitelisted(_from) onlyWhitelisted(_to) {
        super._approve(_from, _to, _value);
    }

    function _safeTransfer(
        address _from,
        address _to,
        uint256 _value
    ) internal onlyWhitelisted(_from) onlyWhitelisted(_to) {
        super._transfer(_from, _to, _value);
    }

    function rejectTransfer(bytes32 transferHash)
        external
        onlyRegistrar
        returns (bool)
    {
        TransferRequest memory transferRequest = _transfers[transferHash];
        if (transferRequest.isTransferFrom) {

            uint256 allowance = allowance(
                transferRequest.from,
                transferRequest.to
            );
            if (allowance != type(uint256).max) {
                _approve(
                    transferRequest.from,
                    transferRequest.to,
                    allowance + transferRequest.value
                );
            }
        }
        _engagedAmount[transferRequest.from] -= transferRequest.value;
        _transfers[transferHash].status = TransferStatus.Rejected;
        emit TransferRejected(transferHash);
        return true;
    }

    function approve(address _to, uint256 _value)
        public
        override(ERC20, ISmartCoin)
        onlyWhitelisted(_msgSender())
        onlyWhitelisted(_to)
        returns (bool)
    {
        
        require(
            _to != address(0),
            "SmartCoin:  approve spender is the zero address"
        );
        require(
            !_hasOngoingApprove[_msgSender()][_to],
            "SmartCoin: owner has ongoing approve request"
        );
        uint256 currentAllowedAmount = super.allowance(_msgSender(), _to);
        if (currentAllowedAmount > 0) super._approve(_msgSender(), _to, 0);
        bytes32 approveHash = EncodingUtils.encodeRequest(
            _msgSender(),
            _to,
            _value,
            _requestCounter
        );
        _approves[approveHash] = ApproveRequest(
            _msgSender(),
            _to,
            _value,
            ApproveStatus.Created
        );
        _hasOngoingApprove[_msgSender()][_to] = true;
        _requestCounter += 1;
        emit ApproveRequested(approveHash, _msgSender(), _to, _value);
        return true;
    }

    function validateApprove(bytes32 approveHash)
        external
        onlyRegistrar
        returns (bool)
    {
        ApproveRequest memory _approveRequest = _approves[approveHash];
        require(
            _approveRequest.status != ApproveStatus.Undefined,
            "SmartCoin: approveHash does not exist"
        );
        require(
            _approveRequest.status == ApproveStatus.Created,
            "SmartCoin: Invalid approve status"
        );
        _safeApprove(
            _approveRequest.from,
            _approveRequest.to,
            _approveRequest.value
        );
        _hasOngoingApprove[_approveRequest.from][_approveRequest.to] = false;
        _approves[approveHash].status = ApproveStatus.Validated;
        emit ApproveValidated(approveHash);
        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    )
        public
        override(ERC20, ISmartCoin)
        onlyWhitelisted(_msgSender())
        onlyWhitelisted(_from)
        onlyWhitelisted(_to)
        returns (bool)
    {
        unchecked {
            super._spendAllowance(_from, _msgSender(), _value); // we know that allowance is bigger then _value
        }
        _initiateTransfer(
            _from,
            _to,
            _value,
            true, // isTransferFrom
            _msgSender()
        );
        return true;
    }

    function rejectApprove(bytes32 _approveHash)
        external
        onlyRegistrar
        returns (bool)
    {
        ApproveRequest memory approveRequest = _approves[_approveHash];
        require(
            approveRequest.status != ApproveStatus.Undefined,
            "SmartCoin: approveHash does not exist"
        );
        require(
            approveRequest.status == ApproveStatus.Created,
            "SmartCoin: Invalid approve status"
        );
        _hasOngoingApprove[approveRequest.from][approveRequest.to] = false;
        _approves[_approveHash].status = ApproveStatus.Rejected;
        emit ApproveRejected(_approveHash);
        return true;
    }

    function transfer(address _to, uint256 _value)
        public
        override(ISmartCoin, ERC20)
        onlyWhitelisted(_msgSender())
        onlyWhitelisted(_to)
        returns (bool)
    {
        _initiateTransfer(_msgSender(), _to, _value, false, address(0));
        return true;
    }

    function _initiateTransfer(
        address _from,
        address _to,
        uint256 _value,
        bool _isTransferFrom,
        address _spender
    ) internal {
        require(
            _from != address(0),
            "SmartCoin: transfer from the zero address"
        );
        require(_to != address(0), "SmartCoin: transfer to the zero address");
        require(
            _availableBalance(_from) >= _value,
            "SmartCoin: Insufficient balance"
        );
        unchecked {
            _engagedAmount[_from] += _value; // Overflow not possible, engagedAmount amount <= balance
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
            TransferStatus.Created,
            _isTransferFrom,
            _spender
        );
        _requestCounter += 1;
        emit TransferRequested(transferHash, _from, _to, _spender, _value);
    }

    function recall(address _from, uint256 _amount)
        external
        override
        onlyRegistrar
        returns (bool)
    {
        require(
            _availableBalance(_from) >= _amount, // _amount should not exceed balance minus engagedAmount amount
            "SmartCoin: transfer amount exceeds balance"
        );
        super._transfer(_from, registrar, _amount);
        return true;
    }

    function burn(uint256 _amount)
        external
        override
        onlyRegistrar
        returns (bool)
    {
        require(
            _availableBalance(registrar) >= _amount, // _amount should not exceed balance minus engagedAmount amount
            "SmartCoin: burn amount exceeds balance"
        );
        super._burn(registrar, _amount);
        return true;
    }

    function mint(address _to, uint256 _amount)
        external
        override
        onlyRegistrar
        onlyWhitelisted(_to)
        returns (bool)
    {
        super._mint(_to, _amount);
        return true;
    }

    function balanceOf(address _addr)
        public
        view
        override(ERC20, ISmartCoin)
        returns (uint256)
    {
        return _availableBalance(_addr); // Overflow not possible: balance >= engagedAmount amount.
    }

    function _availableBalance(address _addr) internal view returns (uint256) {
        unchecked {
            return super.balanceOf(_addr) - _engagedAmount[_addr];
        }
    }

    function engagedAmount(address _addr) public view returns (uint256) {
        return _engagedAmount[_addr];
    }
}
