// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IBEP20.sol";

interface TokenRecipient {
    function receiveApproval(
        address _from,
        uint256 _value,
        address _token,
        bytes calldata _extraData
    ) external;

    function tokenFallback(
        address from,
        uint256 value,
        bytes calldata data
    ) external;
}

contract TrustedContracts is Ownable  {

        mapping(address => bool) public trustedContracts;
        event TrustedContractUpdate(address _contractAddress, bool _added);


        function isContract(address _addr) private view returns (bool) {
        uint256 length;
        assembly {
            length := extcodesize(_addr)
        }
        return (length > 0);
    }

    function addTrustedContracts(address _contractAddress, bool _isActive)
        public
        onlyOwner
    {
        require(
            isContract(_contractAddress),
            "Only contract address can be added"
        );
        trustedContracts[_contractAddress] = _isActive;
        emit TrustedContractUpdate(_contractAddress, _isActive);
    }

     function notifyTrustedContract(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        // if the contract is trusted, notify it about the transfer
        if (trustedContracts[recipient]) {
            TokenRecipient trustedContract = TokenRecipient(recipient);
            bytes memory data;
            trustedContract.tokenFallback(sender, amount, data);
        }
    }

   // Owner of contract can transfer any BEP20 compitable tokens send to this contract
   
    function transferAnyBEP20Token(address _tokenContractAddress, uint256 _value)
        public
        onlyOwner
        returns (bool)
    {
        address owner = owner();
        return IBEP20(_tokenContractAddress).transfer(owner, _value);
    }

}