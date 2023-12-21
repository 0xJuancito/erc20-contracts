//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "../common/access/SuperAdmin.sol";

interface IKnot is IERC20Upgradeable {

}

interface IKnotReceiver {
    function onKnotReceived(address from, address to, uint256 amount) external;
}

interface IKnotAllocate {
    function knotMain() external returns (address);
}

contract Knot is SuperAdmin, ERC20PausableUpgradeable {

    using AddressUpgradeable for address;

    uint256 internal constant TOTAL_AMOUNT = 21e25;

    function initialize() external initializer {
        __ERC20_init_unchained("Karmaverse Knot", "Knot");
        __ERC20Pausable_init();
        __SuperAdmin_init_unchained();
        __Knot_init_unchained();
    }

    function __Knot_init_unchained() internal onlyInitializing {
        _mint(address(this), TOTAL_AMOUNT);
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function setUpAllocateContract(IKnotAllocate allocateContract) external virtual onlySuperAdmin {
        require(allocateContract.knotMain() == address(this), "invalid allocate contract address");
        _transfer(address(this), address(allocateContract), TOTAL_AMOUNT);
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        bool result = super.transfer(recipient, amount);
        if (recipient.isContract()) {
            try IKnotReceiver(recipient).onKnotReceived(_msgSender(), recipient, amount) {

            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    // no IKnotReceiver implementer, do nothing
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
        return result;
    }
}