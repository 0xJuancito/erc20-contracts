//SPDX-License-Identifier: Unlicense
pragma solidity = 0.8.9;

/*
                    .!5B&@@@&5.                                 :G#7                &@@5
               .~Y#@@@@&GYY@@@5                                 &@@Y               ?@@&
           :7G&@@@&G?:   ^G@@&.    ^&@P                        J@@&               .@@@~             .
       ^Y#@@@@#Y~.     ~@@@B!     .&@@Y.:^~7?YPGB#&&@@@@@@@^  .@@@~               P@@B   !?Y5GBB#&&@@5
     5@@@&G7:          .!!???5GB##&@@@@@@@@@@@@&&#BG5J?!~^.   G@@B     ^JGBG!    ^@@@.  Y@@@@&&@@@@G:
    &@@@~                ^@@@@@&#&@@@Y7!~^:.                 ~@@@.  ^G@@@@@@@.   #@@J    ..  !&@@P:
    &@@@!                        #@@Y      .?G#&@@@@@@@@@Y   &@@J.Y&@@G~ G@@B   ?@@&       7&@@5.
    .P@@@@BY~:                  J@@&      P@@@#BPY?7P@@@&   ?@@@B@@&7   .@@@:  .@@@~     ?&@@J
      .~5#@@@@@&GJ~.           :@@@^     #@@P     :G@@@@!  .@@@@@#^     G@@P   G@@G   .J@@@J.  .:^~!?J5PG#&&@@@@@@
           .~JG&@@@@@&P?^.     #@@G     Y@@&    :B@@@@@B   G@@@&^      5@@@:  ?@@@B!?G@@@@@&@@@@@@@@@@@@&&#BP5J
                 :!YB&@@@@@#P7J@@@.    .@@@^  :B@@GY@@@.  ~@@@G..:^~7Y&@@@@@&@@@@@@@@@&B&#BGPYJ7!^::..
  ~B@@~               .:!5B&@@@@@J     G@@G ^B@@B: G@@@BG#@@@@@@@@@@@&G!YBBBG57::^:..
 G@@@G                      G@@@@#!!?Y#@@@@@@@B^   ^#&&&&#GPYJ7!~^:.
G@@@P         ..:^~!?J5GB#&@@@@@@@@@@@&GPBB57.
P@@@@BPPGB&&@@@@@@@@@@@&&#BGY7:..:...
 !G&@@@@@&&#GPY?!~^:..
*/

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/// @title Stablz token
contract Stablz is ERC20Burnable {

    constructor () ERC20("Stablz", "STABLZ") {
        _mint(msg.sender, 100_000_000 * (10 ** decimals()));
    }
}
