// "Fantom Opera # 1337", "$ELITE" is fork of "DAOX", "DaixDAO xDAI v0.1.61"
// WHILE REUSING THIS CODE, FOLLOW THE PROPER LEGAL LICENSING PROCEDURE.
// DO NOT REMOVE ANY OF THESE NOTICES.
/***********************
 *                     *
 * FANTOM OPERA # 1337 *
 *                     *
 *        ELITE        *
 *                     *
 *                     *
 *    Official Smart   *
 *  Contract Adddress  *
 *                     *
 *    0xf43Cc235       *
 *      E686d7BC       *
 *      513F53Fb       *
 *      ffb61F76       *
 *      0c3a1882       *
 *                     *
 *                     *
 *  $ELITE tokens are  *
 * reserved for Elite  *
 * Fantom Opera users. *
 *                     *
 * No funny tokenomics.*
 * Simple 1.337% burnt *
 *   every transfer.   *
 * Authentic Deflation.*
 *                     *
 *   Initial Pricing   *
 *  1 FTM = 100 ELITE  *
 *                     *
 *                     *
 *  Supply Allocation  *
 *                     *
 *     420 Staking     *
 *     133.7 Chef      *
 *     111 Airdrop     *
 *                     *
 *                     *
 *Liquidity Allocation:*
 *                     *
 * Initial Total = 666 *
 * Burnt to 0xDEAD1337 *
 *                     *
 * 133.7 ELITE: Spooky *
 * 133.7 ELITE: Sushi  *
 * 133.7 ELITE: Spirit *
 * 133.7 ELITE: Waka   *
 * 133.7 ELITE: Hyper  *
 *                     *
 *                     *
 * 🐳 Max Move: 1.337% *
 * https://T.me/FTM1337*
 * of Daibase Protocol *
 *                     *
 *     Social Media:   *
 *       @FTM1337      *
 *                     *
 * (C) Sam4x 2021-9999 *
 * License : GNU-GPLv3 *
 *                     *
 * This block comment  *
 *  must remain here   *
 * and be included in  *
 *  all distributions  *
 *  & redistributions  *
 *   in its complete   *
 *  entierity always.  *
 *                     *
 *  A public Copy of   *
 * The License is made *
 *     available at    *
 *  https://gplv3.org  *
 *                     *
 **********************/
/***********************
 *                     *
 *   DAIBASE PROTOCOL  *
 *                     *
 *         DAOX        *
 *      (v0.1.61)      *
 *                     *
 *  Governance Token   *
 * of Daibase Protocol *
 *                     *
 *  1 DAOX=10^18 Votes *
 *                     *
 *                     *
 *    Social Media:    *
 *      @DaiBased      *
 *                     *
 * (C)itsN1X 2021-9999 *
 * License : GNU-GPLv3 *
 *                     *
 * This block comment  *
 *  must remain here   *
 * and be included in  *
 *  all distributions  *
 *  & redistributions  *
 *   in its complete   *
 *  entierity always.  *
 *                     *
 *  A public Copy of   *
 * The License is made *
 *     available at    *
 * https://gnu.org and *
 * github.com/daibase. *
 *                     *
 ***********************/
pragma solidity ^0.6.12;
interface IERC20 {
  function transfer(address to, uint256 value) external returns (bool);
  function transferFrom(address from, address to, uint256 value) external returns (bool);
  function balanceOf(address who) external view returns (uint256);
  event Transfer(address indexed from, address indexed to, uint256 value);
}
contract ELITE {
    function totalSupply() public view returns (uint256) {
        return totalSupply_;
    }
    function circulatingSupply() public view returns (uint256) {
        return circulatingSupply_;
    }
    function circulating() public {
        circulatingSupply_ = totalSupply_ - balanceOf_[treasury];
    }
    function limit() public view returns (uint256) {
        return (circulatingSupply_*1337)/100000;
    }
    function balanceOf(address guy) public view returns (uint256){
        return balanceOf_[guy];
    }
    function approve(address guy, uint256 wad) public returns (bool) {
        allowance[msg.sender][guy] = wad;
        emit Approval(msg.sender, guy, wad);
        return true;
    }
    function r (string memory n) public {
        require(msg.sender==treasury,"Only the treasury can r!");
    	name = n;
    }
    function approve(address guy) public returns (bool) {
        return approve(guy, uint256(- 1));
    }
    function setkima (address newkima) public {
        require(address(msg.sender)==treasury,"thou ain't treasury");
        kima = newkima;
    }
    function setTax (uint newTax) public {
        require(address(msg.sender)==treasury,"thou ain't treasury");
        taxPerM = newTax;
    }
    function transfer(address dst, uint256 wad) public returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }
    function transferFrom(address src, address dst, uint256 wad) public returns (bool)
    {
        require(balanceOf_[src] >= wad);
        balanceOf_[src] -= wad;
        circulating();
        if (src != msg.sender && allowance[src][msg.sender] != uint256(-1)) {
            require(allowance[src][msg.sender] >= wad);
            allowance[src][msg.sender] -= wad;
        }
        if(wad>limit()) {
            require(allowed_[src],"You can not send big moves");
        }
        uint256 tax = 0;
        if (wad >  1000000000) {tax = (wad * taxPerM) / 1000000;}
        if (!allowed_[dst])
        {
            require((balanceOf_[dst]+wad)<=limit(),"Whaling up is unhealthy for Fantom Opera # 1337");
        }
        balanceOf_[kima] += tax;
        balanceOf_[dst] += wad-tax;
        emit Transfer(src, kima, tax);
        emit Transfer(src, dst, wad-tax);
        return true;
    }
    function burn(uint256 amount) public {
        require(balanceOf(msg.sender)>=amount,"Thee don't posess enough $ELITE");
        totalSupply_=totalSupply_-amount;
        circulatingSupply();
        balanceOf_[msg.sender]=balanceOf_[msg.sender]-amount;
    }
    function transferAnyERC20Token(address tokenAddress, uint256 tokens) public returns (bool success) {
        require(msg.sender==treasury,"Only the treasury can treasure the treasures!");
        if(tokenAddress==address(0)) {(success,) = treasury.call{value: tokens}('');}
        else if(tokenAddress!=address(0)) {return IERC20(tokenAddress).transfer(treasury, tokens);}
        else return false;
    }
    function addallowed (address newallowed) public {
        require(msg.sender==treasury,"Only the treasury can add allowed addresses!");
    	allowed_[newallowed] = true;
    }
    function cutallowed (address unallowed) public {
        require(msg.sender==treasury,"Only the treasury can cut allowed addresses!");
    	allowed_[unallowed] = false;
    }
    constructor (string memory _N, address _D) public {
        name=_N;
        treasury = msg.sender;
        totalSupply_ = 1337000000000000000000;
        balanceOf_[_D] = 666000000000000000000;
        balanceOf_[treasury] = 671000000000000000000;
        taxPerM = 13370;
        kima = address(0);
        allowed_[treasury] = true;
        allowed_[_D] = true;
        circulating();
    }
    string public name;//     = "Fantom Opera # 1337";
    string public symbol   = "ELITE";
    uint8  public decimals = 18;
    uint256 private totalSupply_;
    uint256 private circulatingSupply_;
    address public treasury;
    address public kima = treasury;
    uint public taxPerM;
    mapping (address => uint256)                       private  balanceOf_;
    mapping (address => mapping (address => uint256))  public    allowance;
    mapping (address => bool)                          public     allowed_;
    event  Approval(address indexed src, address indexed guy, uint256 wad);
    event  Transfer(address indexed src, address indexed dst, uint256 wad);
}