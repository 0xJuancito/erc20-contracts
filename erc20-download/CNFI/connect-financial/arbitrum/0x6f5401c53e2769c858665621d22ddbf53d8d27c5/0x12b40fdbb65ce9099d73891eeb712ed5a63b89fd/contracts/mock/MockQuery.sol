// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import { MockView } from "./MockView.sol";
import { ViewExecutor } from "../util/ViewExecutor.sol";

contract MockQuery {
  constructor(address sc) public {
    address viewLayer = address(new MockView());
    bytes memory result = ViewExecutor(sc).query(viewLayer, abi.encodeWithSelector(MockView.render.selector));
    (address pCnfi) = abi.decode(result, (address));
    bytes memory response = abi.encode(pCnfi);
    assembly {
      return(add(0x20, response), mload(response))
    }
  }
}
