
// SPDX-License-Identifier: MIT

pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import '@openzeppelin/contracts/access/Ownable.sol';


contract PRISM is ERC20("PRISM", "PRISM"), Ownable {
    using SafeMath for uint256;

    address public stakingContract;
    address public xPRISM;

    constructor() {
        stakingContract = msg.sender;
        _mint(msg.sender, 18000e18);
    }

 
    function burn(address _from, uint256 _amount) external {
        require(msg.sender == xPRISM);
        _burn(_from, _amount);
    }
    
    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }

    function mint(address recipient, uint256 _amount) external {
        require(msg.sender == stakingContract || msg.sender == xPRISM);
        _mint(recipient, _amount);
    }

    function updateMinters(address _xPRISM, address _staking) external onlyOwner {
        xPRISM = _xPRISM;
        stakingContract = _staking;
    }

}
