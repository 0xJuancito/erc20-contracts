// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";

contract CredaCtroller is Ownable {

    mapping (address => bool) private _authorizedMintCaller;

    modifier onlyAuthorizedMintCaller() {
        require(_msgSender() == owner() || _authorizedMintCaller[_msgSender()],"CREDA: MINT_CALLER_NOT_AUTHORIZED");
        _;
    }
    
    function setAuthorizedMintCaller(address caller) onlyOwner external  {
        _authorizedMintCaller[caller] = true;
    }

    function removeAuthorizedMintCaller(address caller) onlyOwner external {
        _authorizedMintCaller[caller] = false;
    }



}