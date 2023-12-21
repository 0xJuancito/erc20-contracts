//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract MebloxToken is ERC20PresetMinterPauser, Ownable {

    using SafeMath for uint256;

    string _name = "Meblox Protocol";
    string _symbol = "MEB";

    constructor() ERC20PresetMinterPauser(_name, _symbol) {}

    uint256 maxSupply = 1000000000 * (10 ** decimals());
    uint256 mintMax = 7000000 * (10 ** decimals());
    uint256 mintInterval = 7*24*60*20;
    uint256 lastMintTime = 0;

    mapping (address => bool) public fromBanList;
    mapping (address => bool) public toBanList;

    event LogMint(address, uint256);
    event LogSetToBanList(address, bool);
    event LogSetFromBanList(address, bool);
    event LogTokenTransfer(address, address, uint256);

    function _beforeTokenTransfer(address _from, address _to, uint256 _amount) internal virtual override(ERC20PresetMinterPauser) {
        require(fromBanList[_from] == false, 'Transfer fail because of from address');
        require(toBanList[_to] == false, 'Transfer fail because of to address');
        emit LogTokenTransfer(_from, _to, _amount);
        super._beforeTokenTransfer(_from, _to, _amount);
    }

    function setToBanList(address _to, bool _status) public onlyOwner {
        toBanList[_to] = _status;
        emit LogSetToBanList(_to, _status);
    }

    function setFromBanList(address _from, bool _status) public onlyOwner {
        fromBanList[_from] = _status;
        emit LogSetFromBanList(_from, _status);
    }

    function mint(address _to, uint256 _amount) public override onlyOwner {
        uint256 _lastBlock = block.number;
        uint256 _lastMintTime = lastMintTime.add(mintInterval);

        require(_amount > 0, 'Amount must be greater than 0!');
        (bool success, uint256 expectedSupply) = SafeMath.tryAdd(totalSupply(), _amount);
        require(success, 'Add Error!');
        require(expectedSupply < maxSupply, 'Over maximum circulation');

        if (expectedSupply > maxSupply.mul(4).div(100)) {
            require(_lastBlock >= _lastMintTime, 'Time has not arrived');
            require(_amount <= mintMax, 'Illegal Amount!');
        }

        emit LogMint(_to, _amount);
        lastMintTime = _lastBlock;
        super.mint(_to, _amount);
    }
}
