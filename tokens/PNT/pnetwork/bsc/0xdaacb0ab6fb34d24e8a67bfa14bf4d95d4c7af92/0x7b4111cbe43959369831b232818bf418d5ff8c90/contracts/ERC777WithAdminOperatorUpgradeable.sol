pragma solidity ^0.6.2;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC777/ERC777Upgradeable.sol";

contract ERC777WithAdminOperatorUpgradeable is Initializable, ERC777Upgradeable {

  address public adminOperator;

  event AdminOperatorChange(address oldOperator, address newOperator);
  event AdminTransferInvoked(address operator);

  function __ERC777WithAdminOperatorUpgradeable_init(
    address _adminOperator
  ) public
    initializer {
      adminOperator = _adminOperator;
    }

  /**
 * @dev Similar to {IERC777-operatorSend}.
 *
 * Emits {Sent} and {IERC20-Transfer} events.
 */
  function adminTransfer(
    address sender,
    address recipient,
    uint256 amount,
    bytes memory data,
    bytes memory operatorData
  )
  public
  {
    require(_msgSender() == adminOperator, "caller is not the admin operator");
    _send(sender, recipient, amount, data, operatorData, false);
    emit AdminTransferInvoked(adminOperator);
  }

  /**
   * @dev Only the actual admin operator can change the address
   */
  function setAdminOperator(address adminOperator_) public {
    require(_msgSender() == adminOperator, "Only the actual admin operator can change the address");
    emit AdminOperatorChange(adminOperator, adminOperator_);
    adminOperator = adminOperator_;
  }


}
