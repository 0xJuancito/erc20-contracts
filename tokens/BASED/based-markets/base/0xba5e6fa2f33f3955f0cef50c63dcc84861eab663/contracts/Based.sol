// SPDX-License-Identifier: MIT

/* ----------------------------------------------------------------------------------------------------------------------------------------------

BASED MARKETS on @BuildOnBase coinbase LayerTwo aka BASE
 https://based.markets < official website (going live 10th august)
 https://app.based.markets < trading interface (going live 1st september)
 For more information check out our documentation @ docs.based.markets


__/\\\\\\\\\\\\\_______/\\\\\\\\\________/\\\\\\\\\\\____/\\\\\\\\\\\\\\\__/\\\\\\\\\\\\____        
 _\/\\\/////////\\\___/\\\\\\\\\\\\\____/\\\/////////\\\_\/\\\///////////__\/\\\////////\\\__       
  _\/\\\_______\/\\\__/\\\/////////\\\__\//\\\______\///__\/\\\_____________\/\\\______\//\\\_      
   _\/\\\\\\\\\\\\\\__\/\\\_______\/\\\___\////\\\_________\/\\\\\\\\\\\_____\/\\\_______\/\\\_     
    _\/\\\/////////\\\_\/\\\\\\\\\\\\\\\______\////\\\______\/\\\///////______\/\\\_______\/\\\_    
     _\/\\\_______\/\\\_\/\\\/////////\\\_________\////\\\___\/\\\_____________\/\\\_______\/\\\_   
      _\/\\\_______\/\\\_\/\\\_______\/\\\__/\\\______\//\\\__\/\\\_____________\/\\\_______/\\\__  
       _\/\\\\\\\\\\\\\/__\/\\\_______\/\\\_\///\\\\\\\\\\\/___\/\\\\\\\\\\\\\\\_\/\\\\\\\\\\\\/___ 
        _\/////////////____\///________\///____\///////////_____\///////////////__\////////////_____

__/\\\\____________/\\\\_____/\\\\\\\\\_______/\\\\\\\\\______/\\\________/\\\__/\\\\\\\\\\\\\\\__/\\\\\\\\\\\\\\\_____/\\\\\\\\\\\___        
 _\/\\\\\\________/\\\\\\___/\\\\\\\\\\\\\___/\\\///////\\\___\/\\\_____/\\\//__\/\\\///////////__\///////\\\/////____/\\\/////////\\\_       
  _\/\\\//\\\____/\\\//\\\__/\\\/////////\\\_\/\\\_____\/\\\___\/\\\__/\\\//_____\/\\\___________________\/\\\________\//\\\______\///__      
   _\/\\\\///\\\/\\\/_\/\\\_\/\\\_______\/\\\_\/\\\\\\\\\\\/____\/\\\\\\//\\\_____\/\\\\\\\\\\\___________\/\\\_________\////\\\_________     
    _\/\\\__\///\\\/___\/\\\_\/\\\\\\\\\\\\\\\_\/\\\//////\\\____\/\\\//_\//\\\____\/\\\///////____________\/\\\____________\////\\\______    
     _\/\\\____\///_____\/\\\_\/\\\/////////\\\_\/\\\____\//\\\___\/\\\____\//\\\___\/\\\___________________\/\\\_______________\////\\\___   
      _\/\\\_____________\/\\\_\/\\\_______\/\\\_\/\\\_____\//\\\__\/\\\_____\//\\\__\/\\\___________________\/\\\________/\\\______\//\\\__  
       _\/\\\_____________\/\\\_\/\\\_______\/\\\_\/\\\______\//\\\_\/\\\______\//\\\_\/\\\\\\\\\\\\\\\_______\/\\\_______\///\\\\\\\\\\\/___ 
        _\///______________\///__\///________\///__\///________\///__\///________\///__\///////////////________\///__________\///////////_____


---------------------------------------------------------------------------------------------------------------------------------------------- */

pragma solidity 0.8.17;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IDibsRewarder.sol";

contract Based is ERC20 {
    string public constant domain = "https://based.markets";
    address public admin;

    uint256 public constant maxSupply = 1_000_000e18;

    address public dibsRewarder;
    uint256 public startTimestamp;
    mapping(uint256 => bool) public isRewardMinted;

    event FillDibsRewarder(address sender, uint256 day, uint256 amount);

    constructor(address admin_) ERC20("based.markets", "BASED") {
        admin = admin_;

        _mint(admin, 350_000e18);
    }

    function initialize(
        address dibsRewarder_,
        uint256 startTimestamp_
    ) external {
        require(msg.sender == admin, "ONLY ADMIN");
        require(
            dibsRewarder_ != address(0) && startTimestamp_ > block.timestamp,
            "BAD PARAMS"
        );

        dibsRewarder = dibsRewarder_;
        startTimestamp = startTimestamp_;

        _approve(address(this), dibsRewarder, maxSupply - totalSupply());

        admin = address(0);
    }

    function getDibsRewardAmount(uint256 day) public view returns (uint256) {
        if (day < 365) return 821917808219178000000;
        if (day < 365 * 2) return 547945205479452000000;
        if (day < 365 * 3) return 273972602739726000000;
        if (day < 365 * 4) return 136986301369863000000;
        if (maxSupply - totalSupply() < 136986301369863000000)
            return maxSupply - totalSupply();
        return 0;
    }

    function fillDibsRewarder(uint256 day) external {
        require(block.timestamp >= startTimestamp, "NOT STARTED");
        require(
            startTimestamp + day * 1 days < block.timestamp,
            "NOT REACHED DAY"
        );

        if (!isRewardMinted[day]) {
            isRewardMinted[day] = true;

            uint256 amount = getDibsRewardAmount(day);
            if (amount > 0) {
                _mint(address(this), amount);
                IDibsRewarder(dibsRewarder).fill(day, amount);

                emit FillDibsRewarder(msg.sender, day, amount);
            }
        }
    }
}

/* ----------------------------------------------------------------------------------------------------------------------------------------------

               _                               _ _                 _   _                                      
               | |                             | | |               | | (_)                                     
  _ __   ___   | |_ ___  __ _ _ __ ___     __ _| | | ___   ___ __ _| |_ _  ___  _ __                           
 | '_ \ / _ \  | __/ _ \/ _` | '_ ` _ \   / _` | | |/ _ \ / __/ _` | __| |/ _ \| '_ \                          
 | | | | (_) | | ||  __/ (_| | | | | | | | (_| | | | (_) | (_| (_| | |_| | (_) | | | |                         
 |_| |_|\___/   \__\___|\__,_|_| |_| |_|  \__,_|_|_|\___/ \___\__,_|\__|_|\___/|_| |_|                         
 | |               | |      | |                                                                                
 | |_ _ __ __ _  __| | ___  | |_ ___     ___  __ _ _ __ _ __                                                   
 | __| '__/ _` |/ _` |/ _ \ | __/ _ \   / _ \/ _` | '__| '_ \                                                  
 | |_| | | (_| | (_| |  __/ | || (_) | |  __/ (_| | |  | | | |                                                 
  \__|_|  \__,_|\__,_|\___|  \__\___/   \___|\__,_|_|  |_| |_|                                                 
  _      _____       _            _            _                                                               
 | |    |  __ \     | |          | |          | |                                                              
 | |    | |__) |__  | | ___   ___| | _____  __| |                                                              
 | |    |  ___/ __| | |/ _ \ / __| |/ / _ \/ _` |                                                              
 | |____| |   \__ \ | | (_) | (__|   <  __/ (_| |                                                              
 |______|_|   |___/ |_|\___/_\___|_|\_\___|\__,_|              _ _ _   _                                       
             | |           | |                                (_) | | | |                                      
   ___  _ __ | |_   _    __| |_   _ _ __ ___  _ __   __      ___| | | | |__   ___   _   _  ___  _   _ _ __ ___ 
  / _ \| '_ \| | | | |  / _` | | | | '_ ` _ \| '_ \  \ \ /\ / / | | | | '_ \ / _ \ | | | |/ _ \| | | | '__/ __|
 | (_) | | | | | |_| | | (_| | |_| | | | | | | |_) |  \ V  V /| | | | | |_) |  __/ | |_| | (_) | |_| | |  \__ \
  \___/|_| |_|_|\__, |  \__,_|\__,_|_| |_| |_| .__/    \_/\_/ |_|_|_| |_.__/ \___|  \__, |\___/ \__,_|_|  |___/
                 __/ |                       | |                                     __/ |                     
                |___/                        |_|                                    |___/                      

Welcome to intent-based derivatives for degenerates.
BASED Markets are Intent-based 
derivatives.

NO LPs.
NO OrderBooks
NO Trading Based on Oracles Prices.
NO Infinite Slippage.
NO pre locked liquidity.

Based Markets are 100% 
economically sound 
& red-pilled.



Why are these markets so Based?
PartyA Intent 
1 BTC Long

PartyB responds 
1 BTC Short
 
Alice (PartyB) sends an Intent to the contract (1 BTC Long),
Bob (PartyB) responds, and opens a countertrade (1 BTC Short).
Both sides lock collateral and are immutably 
locked into the trade.
3 Party Liquidators are now observing their position to 
ensure they are solvent at all times.



learn more on https://docs.based.markets

---------------------------------------------------------------------------------------------------------------------------------------------- */
