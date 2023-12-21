// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
contract MedPingBalanceBox is Ownable{

  using SafeMath for uint256;

 
    uint256 lockStageGlobal;
    address migrator;

    mapping(address=>bool)crowdsaleWhitelist;
    mapping(address=>bool)migratorsList;
    mapping(uint256 => mapping(address=>bool)) seedProvisionsTrack;
    mapping(uint256 => mapping(address=>bool)) idoProvisionsTrack;
    /** If false we are are in transfer lock up period.*/
    bool public released = false;
    
    uint256 firstListingDate = 1; //date for first exchange listing
    
    struct boxAllowance{uint256 seed_total; uint256 ido_total; uint256 allowance; uint256 spent; uint lockStage;}   
    mapping(address => boxAllowance) boxAllowances; //early investors allowance profile
    mapping(address => bool) earlyInvestors;//list of early investors

    uint256 [] seedProvisionDates;
    uint256 [] idoProvisionDates;

    /** MODIFIER: Limits token transfer until the lockup period is over.*/
    modifier canTransfer() {
        if(!released) {
            require(crowdsaleWhitelist[msg.sender],"you are not permitted to make transactions, not whitelisted");
        }
        _;
    }
    modifier onlyMigrators() {
        require(migratorsList[msg.sender],"you are not permitted to make transactions, Only Migrators");
        _;
    }
    /** MODIFIER: Limits and manages early investors transfer.
    *check if is early investor and if within the 30days constraint
    */
    modifier investorChecks(uint256 _value,address _sender, uint256 bal){
        if(isEarlyInvestor(_sender)){
            boxAllowance storage box = boxAllowances[_sender]; 
            if((firstListingDate + (13 * 30 days)) > block.timestamp){ //is investor and within 13 months constraint 
                 if(!isSeedAllowanceProvisioned(_sender,lockStageGlobal)){
                    provisionSeedBoxAllownces(_sender,box.lockStage); 
                 }
                 
            }
            if((firstListingDate + (10 * 30 days)) > block.timestamp){ //is investor and within 13 months constraint 
                 if(!isIdoAllowanceProvisioned(_sender,lockStageGlobal)){
                    provisionIdoBoxAllownces(_sender,box.lockStage); 
                 }
                 
            }
            require((bal - _value) > box.allowance,"You have to reserve a minimum amount of balance as an early investor. check MPG tokenomics"); //validate spending amount
            require(updateBoxAllownces(_value,_sender)); //update box spent 
        }
        _;
    }
    constructor()
    Ownable() {
    }
        /** Allows only the owner address to relase the tokens into the wild */
    function releaseTokenTransfer() onlyOwner() public {
            released = true;       
    }
 
        /**Set the Migrator address. **/
    function setMigrator(address _migrator) onlyOwner() public {
        migrator = _migrator;
    }
    function setFirstListingDate(uint256 _date) public onlyOwner() returns(bool){
        firstListingDate = _date; 
        uint firstReleaseDate = _date + (3 * 30 days); //3months after the listing date
        seedProvisionDates.push(firstReleaseDate);
        idoProvisionDates.push(firstListingDate); //same date as listing date
        for (uint256 index = 1; index <= 10; index++) { //remaining released monthly after the first release
            uint nextSeedReleaseDate = firstReleaseDate +(index * 30 days);
            seedProvisionDates.push(nextSeedReleaseDate);

            uint nextIdoReleaseDate = firstListingDate +(index * 30 days);
            idoProvisionDates.push(nextIdoReleaseDate);
        }
        return true; 
    }
    /** box early investments per tokenomics.*/
    function addToBox(uint256 _seed_total,uint256 _ido_total, address _investor) public onlyMigrators(){
        //check if the early investor's address is not registered
        if(!earlyInvestors[_investor]){
            boxAllowance memory box;
            box.seed_total = _seed_total;
            box.ido_total = _ido_total;
            box.allowance = 0;
            box.spent = 0;
            boxAllowances[_investor] = box;
            earlyInvestors[_investor]=true;
        }else{
            boxAllowance storage box = boxAllowances[_investor];
            box.seed_total +=  _seed_total;
            box.ido_total +=  _ido_total;
        }
    }
  
    function investorAllowance(address investor) public view returns (uint256 presale_total, uint256 privatesale_total,uint256 allowance,uint256 spent, uint lockStage){
        boxAllowance storage box =  boxAllowances[investor];
        return (box.seed_total,box.ido_total,box.allowance,box.spent,box.lockStage);
    }
     /** update allowance box.*/
    function updateBoxAllownces(uint256 _spending, address _sender) internal returns (bool){
        boxAllowance storage box = boxAllowances[_sender];
        box.allowance -= _spending;
        box.spent     += _spending;
        return true; 
    }
     /** provision allowance box.*/
    function provisionSeedBoxAllownces(address _beneficiary,uint _lockStage) internal  returns (bool){
        if (block.timestamp >= seedProvisionDates[0]) {
            boxAllowance storage box = boxAllowances[_beneficiary];
            uint256 seedInital = box.seed_total;
                require(_lockStage <= 11,"lock stage cannot be greater than 11");
            if(box.lockStage < 1){//first allowance provision
                if(seedInital > 0){
                    uint first_allow = (box.seed_total.mul(20 *100)).div(10000);
                    box.allowance += first_allow; 
                    box.seed_total -= seedInital;               
                }
                    box.lockStage = 1;
            }else if(box.lockStage >= 1){//following allowance provision
                    if(seedInital > 0){
                        uint allow = (box.seed_total.mul(10 *100)).div(10000);
                        box.allowance += allow;
                        
                    }
                    box.lockStage += 1;  
            }
        seedProvisionsTrack[lockStageGlobal][_beneficiary] = true;
        } 
        return true; 
    }
    function provisionIdoBoxAllownces(address _beneficiary,uint _lockStage) internal  returns (bool){
         if (block.timestamp >= idoProvisionDates[0]) {
             boxAllowance storage box = boxAllowances[_beneficiary];
            uint256 idoInital  =  box.ido_total;
            require(_lockStage <= 11,"lock stage cannot be greater than 11");
            if(box.lockStage < 1){//first allowance provision
                if(idoInital > 0){
                uint first_allow = (box.ido_total.mul(30 *100)).div(10000);
                box.allowance += first_allow;
                box.ido_total -= idoInital;
                } 
                box.lockStage = 1;
                    
            }else if(box.lockStage >= 1){//following allowance provision
                    if(idoInital > 0){
                        uint _allow = (box.ido_total.mul(10 *100)).div(10000);
                        box.allowance += _allow; 
                    }
                    box.lockStage += 1;
                    
            }
            idoProvisionsTrack[lockStageGlobal][_beneficiary] = true;
         }
        
        return true; 
    }
    function isSeedAllowanceProvisioned(address _beneficiary,uint _lockStageGlobal) public view returns (bool){
         return seedProvisionsTrack[_lockStageGlobal][_beneficiary];
    }
    function isIdoAllowanceProvisioned(address _beneficiary,uint _lockStageGlobal) public view returns (bool){
         return idoProvisionsTrack[_lockStageGlobal][_beneficiary];
    }
   
    function isEarlyInvestor(address investor) public view returns(bool){
        if(earlyInvestors[investor]){
            return true; 
        }
        return false;
    }
    function getFirstListingDate() public view returns(uint256){
        return firstListingDate;
    }
    function getSeedProvisionDates() public view returns (uint256 [] memory){
        return seedProvisionDates;
    }

    function getIdoProvisionDates() public view returns (uint256 [] memory){
        return idoProvisionDates;
    }
      
    /**white lsit address to be able to transact during crowdsale. **/
    function whiteListAddress(address _add) onlyOwner() public { 
        crowdsaleWhitelist[_add] = true;
    }
    function iswhiteListAddress(address _add) public view returns(bool) { 
        if(crowdsaleWhitelist[_add]){
            return true;
        }
        return false;
    }
    /** add address to be able to conduct migration. **/
    function addMigratorAddress(address _add) onlyOwner() public { 
        migratorsList[_add] = true;
    }
    function isMigrator(address _add) public view returns(bool) { 
        if(migratorsList[_add]){
            return true;
        }
        return false;
    }
    function updateLockStage(uint256 _stage) onlyOwner() public returns (bool){
         lockStageGlobal = _stage;
         return true;
    }
}
