// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract USDEX is ERC20Permit, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private _burners;
    EnumerableSet.AddressSet private _minters;

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

    function mintersCount() external view returns (uint256) {
        return _minters.length();
    }

    function minters(uint256 index) external view returns (address) {
        return _minters.at(index);
    }

    function mintersContains(address minter) external view returns (bool) {
        return _minters.contains(minter);
    }

    function mintersList(uint256 offset, uint256 limit) external view returns (address[] memory output) {
        uint256 mintersLength = _minters.length();
        if (offset >= mintersLength) return output;
        uint256 to = offset + limit;
        if (mintersLength < to) to = mintersLength;
        output = new address[](to - offset);
        for (uint256 i = 0; i < output.length; i++) output[i] = _minters.at(offset + i);
    }

    event BurnersAdded(address[] addedBurners);
    event BurnersRemoved(address[] removedBurners);
    event MintersAdded(address[] addedMinters);
    event MintersRemoved(address[] removedMinters);

    constructor(
        uint256 initialSupply,
        address[] memory burners_,
        address[] memory minters_
    ) ERC20("USDEX+", "USDEX+") ERC20Permit("USDEX+") {
        require(initialSupply > 0, "USDEX+: Supply not positive");
        _mint(msg.sender, initialSupply);
        for (uint256 i = 0; i < burners_.length; i++) _burners.add(burners_[i]);
        for (uint256 j = 0; j < minters_.length; j++) _minters.add(minters_[j]);
    }

    function burn(address from, uint256 amount) external returns (bool) {
        require(msg.sender == from || _burners.contains(msg.sender), "USDEX+: Can't burn from other wallets");
        _burn(from, amount);
        return true;
    }

    function mint(address to, uint256 amount) external returns (bool) {
        require(_minters.contains(msg.sender), "USDEX+: Can be executed only by minters");
        require(amount > 0, "USDEX+: Amount not positive");
        _mint(to, amount);
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

    function addMinters(address[] memory minters_) external onlyOwner returns (bool) {
        for (uint256 i = 0; i < minters_.length; i++) _minters.add(minters_[i]);
        emit MintersAdded(minters_);
        return true;
    }

    function removeMinters(address[] memory minters_) external onlyOwner returns (bool) {
        for (uint256 i = 0; i < minters_.length; i++) _minters.remove(minters_[i]);
        emit MintersRemoved(minters_);
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
