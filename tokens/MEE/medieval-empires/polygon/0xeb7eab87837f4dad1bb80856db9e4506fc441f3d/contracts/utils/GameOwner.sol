// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract GameOwner is Ownable {
    address private gameOwnerAddress;

    using Address for address;

    event SetGameOwnerEvent(address indexed gameOwner);

    /**
     * Constructor method which calls initial setters for all the contracts
     */
    constructor(address _gameOwnerAddress) {
        require(_gameOwnerAddress != address(0), "GameOwner: game owner address can't be 0x0");
        gameOwnerAddress = _gameOwnerAddress;
    }

    /**
     * Setter method for gameOwnerAddress variable
     */
    function setGameOwnerAddress(address _newAddress) external onlyGameOwner {
        require(_newAddress != address(0), "GameOwner: game owner address can't be 0x0");
        gameOwnerAddress = _newAddress;
        emit SetGameOwnerEvent(_newAddress);
    }

    /**
     * Getter method for gameOwnerAddress variable which returns address
     * @return address
     */
    function getGameOwnerAddress() external view returns(address) {
        return gameOwnerAddress;
    }

    /**
     * Method which checks if the address is game owner address
     * @return bool
     **/
    function isGameOwnerAddress() internal view returns(bool) {
        return gameOwnerAddress == _msgSender();
    }

    /**
     * Modifier which restricts method execution to onlyGameOwner address
     */
    modifier onlyGameOwner() {
        require(isGameOwnerAddress(), "GameOwner: caller is not the game address");
        _;
    }
}
