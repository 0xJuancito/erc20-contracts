// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract GDEX is ERC20Permit, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private _burners;

    function burnersCount() external view returns (uint256) {
        return _burners.length();
    }

    function burners(uint256 index) external view returns (address) {
        return _burners.at(index);
    }

    function burnersContains(address burner) external view returns (bool) {
        return _burners.contains(burner);
    }

    function burnersList(uint256 offset, uint256 limit) external view returns (address[] memory output) {
        uint256 burnersLength = _burners.length();
        if (offset >= burnersLength) return output;
        uint256 to = offset + limit;
        if (burnersLength < to) to = burnersLength;
        output = new address[](to - offset);
        for (uint256 i = 0; i < output.length; i++) output[i] = _burners.at(offset + i);
    }

    event BurnersAdded(address[] addedBurners);
    event BurnersRemoved(address[] removedBurners);

    constructor(
        uint256 initialSupply,
        address[] memory burners_
    ) ERC20("DexFi Governance", "gDEX") ERC20Permit("DexFi Governance") {
        require(initialSupply > 0, "gDEX: InitialSupply not positive");
        _mint(msg.sender, initialSupply);
        for (uint256 i = 0; i < burners_.length; i++) _burners.add(burners_[i]);
    }

    function burn(address from, uint256 amount) external returns (bool) {
        require(msg.sender == from || _burners.contains(msg.sender), "gDEX: Can't burn from other wallets");
        _burn(from, amount);
        return true;
    }

    function addBurners(address[] memory burners_) external onlyOwner returns (bool) {
        for (uint256 i = 0; i < burners_.length; i++) _burners.add(burners_[i]);
        emit BurnersAdded(burners_);
        return true;
    }

    function removeBurners(address[] memory burners_) external onlyOwner returns (bool) {
        for (uint256 i = 0; i < burners_.length; i++) _burners.remove(burners_[i]);
        emit BurnersRemoved(burners_);
        return true;
    }

    function foreignTokensRecover(
        IERC20 _token,
        uint256 _amount,
        address _to
    ) external onlyOwner returns (bool) {
        _token.transfer(_to, _amount);
        return true;
    }
}
