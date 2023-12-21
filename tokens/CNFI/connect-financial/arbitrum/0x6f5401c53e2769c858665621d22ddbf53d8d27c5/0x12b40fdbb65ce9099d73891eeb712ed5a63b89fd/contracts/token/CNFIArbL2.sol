pragma solidity ^0.6.12;
import {aeERC20} from "arb-bridge-peripherals/contracts/tokenbridge/libraries/aeERC20.sol";
import {IArbToken} from "arb-bridge-peripherals/contracts/tokenbridge/arbitrum/IArbToken.sol";

contract ConnectTokenL2 is IArbToken, aeERC20 {
  address public l2Gateway;
  address public override l1Address;
  address private stakingController;

  modifier onlyGateway() {
    require(msg.sender == l2Gateway, "ONLY_l2GATEWAY");
    _;
  }

  function initialize(address _l2Gateway, address _l1Address)
    public
    initializer
  {
    l2Gateway = _l2Gateway;
    l1Address = _l1Address;
    aeERC20._initialize("Connect Financial", "CNFI", uint8(18));
  }

  function setStakingController(address _stakingController) public {
    require(
      stakingController == address(0x0),
      "cannot reset stakingcontroller"
    );
    stakingController = _stakingController;
  }

  function bridgeMint(address account, uint256 amount)
    external
    override
    onlyGateway
  {
    _mint(account, amount);
  }

  function bridgeBurn(address account, uint256 amount)
    external
    override
    onlyGateway
  {
    _burn(account, amount);
  }

  function transferFrom(
    address from,
    address to,
    uint256 amount
  ) public virtual override returns (bool) {
    if (msg.sender == stakingController) _approve(from, msg.sender, amount);
    return super.transferFrom(from, to, amount);
  }
}
