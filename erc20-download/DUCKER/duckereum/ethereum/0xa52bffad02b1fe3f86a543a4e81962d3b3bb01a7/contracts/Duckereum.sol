// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;


/*
*         _          _          _          _          _          _          _           
*       >(')____,  >(')____,  >(')____,  >(')____,  >(')____,  >(')____,  >(')____,  
*         (` =~~/    (` =~~/    (` =~~/    (` =~~/    (` =~~/    (` =~~/    (` =~~/   
*     ^~^~^`---'~^~^~^`---'~^~^~^`---'~^~^~^`---'~^~^~^`---'~^~^~^`---'~^~^~^`---'~^~^
*
*     GM DUCKERS,
*
*     Ah, we see you. You're thinking it's yet another meme currency... 
*     You're wrong. Well, yes, of course, Duckereum is a meme currency, 
*     but it is (according to us) the only one that exists besides Dogecoin.
*
*     Duckereum has no other purpose than to make crypto fun again.
*     We have no marketcap goals, we don't encourage people to buy,
*     we don't use weird techniques to inflate the US dollar value of our token.
*     
*     We're here to have a good time with you. Every week, 
*     a meme contest is organised by the team, the community votes the winner
*     who then receives a number of Duckereums known in advance,
*     regardless of its value in US dollars. Every week, 
*     Mark Duckerberg, the project's creator, keeps a diary
*     in which he tells the story of the Duckereum adventure. 
*      
*     No burn, no tax, no inflation, no deflation, no buy back,
*     locked liquidity and renounced contract.
*     Community spirit and lightness are at the heart of Duckereum.
*     For us, it's all about the adventure, not the ranking on CoinMarketCap.
*     Do you like it? Then, join us!
*     You don't have to buy Duckereum, just bring your good humour and sympathy,
*     and take part in our meme contests to win some Duckereum.
*     
*     See you soon, duckers!
*     
*     Website:      https://duckereum.com
*     Reddit:       https://reddit.com/r/duckereum
*     Twitter:      https://twitter.com/duckereum
*     Telegram:     https://t.me/duckereum
*     Medium:       https://duckereum.medium.com
*     
*
*     888888ba                    dP                                                      
*     88    `8b                   88                                                      
*     88     88 dP    dP .d8888b. 88  .dP  .d8888b. 88d888b. .d8888b. dP    dP 88d8b.d8b. 
*     88     88 88    88 88'  `"" 88888"   88ooood8 88'  `88 88ooood8 88    88 88'`88'`88 
*     88    .8P 88.  .88 88.  ... 88  `8b. 88.  ... 88       88.  ... 88.  .88 88  88  88 
*     8888888P  `88888P' `88888P' dP   `YP `88888P' dP       `88888P' `88888P' dP  dP  dP   
*                                                                                                           
*                                         
*
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&BY?!~7YPGPYYY5G#&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@P7~^:..........:::~Y@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&J!!!~...............^J@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@5?5?!~~..............~^Y@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#P@@Y~~~^............^!?~&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&B#Y~~~J?~:::::::~~..:P@5&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@G7!~~~YPPP55YYYYYJJ::^^&&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@G?~~~!5GGGPGPYYYYYJY!.~!Y&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@J~~~~~YBGGGGGPP5PP5Y5Y:.~?B@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@J.::.!YGGGGGGPPP55PPPPP7..:^P@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@5....~Y5555YYYJJ?JJJJY55Y:...:P@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@@@@@@@@@@@@@@@@@@@@@@P:...:!~~~!!!!^^^^~~!777777~. .^&@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@@@@@@@@@@@@@@@@@@@@@@!......:^^^^^^^^^^^^^^~~^^^^... J@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@@@@@@@@@@@@@@@@@@@@@@Y.....  ^^^^^^^^^^^^^^^^^:......J@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@@@@@@@@@@@@@@@@@@@@@@P.....        .:......::.   ....B@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@@@@@@@@@@@@@@@@@@@@@@&^....                     ... 7@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@B^^::................  ..... 7@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@Y~~~~^^^^^^^^^^^:..........5@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@7~~~~!^::^^:::^^........:#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@5~~~~:.................~@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@P~~~~^................^B@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@7~~~~.................!&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@J!~~~~:...............:&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@@@@@@@@@@@@@@@@@@@@@#Y?~~~~~~^:.......:.....^P@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@@@@@@@@@@@@@@@@@BY!!~~~~~~~~!:.............:!&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@@@@@@@@@@@@@@@57~~~~~~~~~~~~:..............:5@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@@@@@@@@@@@@#5J~^^^~~~~~^::...............^:^G@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@@@@@@@@@&P5!^^~~^:~~~~~....................:5@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@@@@@@@&Y~~~~^^~~~~~~^:......................~?&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@@@@@@@B~~~~~^~~~~^~~........................^~7@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@@@@&GP?~~~~~^^~~~^^..........................~B@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@@#5?^~^^~^:~:~~::.. .........................:Y@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*@@@@@@G^^^::.::^^^:^^^.............................:~7#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*
*
*     
*     Duckereum, by Mark Duckerberg
*            	    Warren Duckett 
*            	    M0THER Ducker 
*
*
*/


import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Duckereum is ERC20, Ownable {

    using SafeMath for uint256;

    mapping(address => bool) private pair;
    bool public tradingOpen;
    uint256 public _maxWalletSize = 1000000 * 10 ** decimals();
    uint256 private _totalSupply = 100000000 * 10 ** decimals();

    constructor() ERC20("Duckereum", "DUCKER") {

        _mint(msg.sender, 100000000 * 10 ** decimals());
        
    }

    function addPair(address toPair) public onlyOwner {
        require(!pair[toPair], "This pair is already excluded");
        pair[toPair] = true;
    }

    function setTrading(bool _tradingOpen) public onlyOwner {
        tradingOpen = _tradingOpen;
    }

    function setMaxWalletSize(uint256 maxWalletSize) public onlyOwner {
        _maxWalletSize = maxWalletSize;
    }

    function removeLimits() public onlyOwner{
        _maxWalletSize = _totalSupply;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

       if(from != owner() && to != owner()) {

            //Trade start check
            if (!tradingOpen) {
                require(from == owner(), "TOKEN: This account cannot send tokens until trading is enabled");
            }

            //buy 
            
            if(from != owner() && to != owner() && pair[from]) {
                require(balanceOf(to) + amount <= _maxWalletSize, "TOKEN: Amount exceeds maximum wallet size");
                
            }
            
            // transfer
           
            if(from != owner() && to != owner() && !(pair[to]) && !(pair[from])) {
                require(balanceOf(to) + amount <= _maxWalletSize, "TOKEN: Balance exceeds max wallet size!");
            }

       }

       super._transfer(from, to, amount);

    }

}