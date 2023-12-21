//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.6;

import './SafeMath.sol';
import './BEP20.sol';

contract CentricSwap is BEP20 {
    using SafeMath for uint256;

    address public riseContract;

    constructor(address _mintSaver) BEP20('Centric SWAP', 'CNS', 8) {
        _mint(_mintSaver, 0);
    }

    modifier onlyRise() {
        require(msg.sender == riseContract, 'CALLER_MUST_BE_RISE_CONTRACT_ONLY');
        _;
    }

    function setRiseContract(address _riseContractAddress) external onlyContractOwner() {
        require(_riseContractAddress != address(0), 'RISE_CONTRACT_CANNOTBE_NULL_ADDRESS');
        require(riseContract == address(0), 'RISE_CONTRACT_ADDRESS_IS_ALREADY_SET');
        riseContract = _riseContractAddress;
    }

    function mintFromRise(address to, uint256 value) external onlyRise returns (bool _success) {
        _mint(to, value);
        return true;
    }

    function burnFromRise(address tokensOwner, uint256 value)
        external
        virtual
        onlyRise
        returns (bool _success)
    {
        _burn(tokensOwner, value);
        return true;
    }
}
