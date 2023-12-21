pragma solidity ^0.5.16;


import "./BerryStorage.sol";
import "./BerryTransfer.sol";
import "./BerryDispute.sol";
import "./Utilities.sol";
/**
* itle Berry Stake
* @dev Contains the methods related to miners staking and unstaking. Berry.sol
* references this library for function's logic.
*/

library BerryStake {
    event NewStake(address indexed _sender); //Emits upon new staker
    event StakeWithdrawn(address indexed _sender); //Emits when a staker is now no longer staked
    event StakeWithdrawRequested(address indexed _sender); //Emits when a staker begins the 7 day withdraw period

    /*Functions*/

    /**
    * @dev This function stakes the five initial miners, sets the supply and all the constant variables.
    * This function is called by the constructor function on BerryMaster.sol
    */
    function init(BerryStorage.BerryStorageStruct storage self) public {
        require(self.uintVars[keccak256("decimals")] == 0, "Too many decimals");
        //Give this contract 6000 Berry Tributes so that it can stake the initial 6 miners
        BerryTransfer.updateBalanceAtNow(self.balances[address(this)], 5000000e18);

        // //the initial 5 miner addresses are specfied below
        // //changed payable[5] to 6
        address payable[6] memory _initalMiners = [
address(0x1b906684efa10C536E4ADbAB63489acE94fE0724),
address(0x12d13EA7869eCBFE703Fb77C0259614b8b927b62),
address(0x1ca1Cd7FB013DEd91B24403B008C5E65C8367E1d),
address(0x95676256f152D3b0E1511a1ED00617aF34FBcC13),
address(0x1d49038242c9CCd299543a765fdf927d0c05F37d),
address(0x18358A7d4A72fAe65d0b30c80CC85CD2332243E3)
        ];
        //Stake each of the 5 miners specified above
        for (uint256 i = 0; i < 6; i++) {
            //6th miner to allow for dispute
            //Miner balance is set at 1000e18 at the block that this function is ran
            BerryTransfer.updateBalanceAtNow(self.balances[_initalMiners[i]], 1000e18);

            newStake(self, _initalMiners[i]);
        }

        // for add tip, if accounts[0] will overwrite 1000 staking
        BerryTransfer.updateBalanceAtNow(self.balances[msg.sender], 10000e18);
        
        // for Mining liquidity 1875000 + for IFO 2000000
        BerryTransfer.updateBalanceAtNow(self.balances[address(0xa2Dd53Cdf42C49963BD8d4E505d7C921b6558F61)], 3875000e18);
        // for Ecosystem data 2875000 - 6000(6 miners staking) - 10000(for add tip)
        BerryTransfer.updateBalanceAtNow(self.balances[address(0x55d166E9b4b20352c18D66BdcC828eD4A9113C19)], 2859000e18);
        // for Team, will vesting for 2 years
        BerryTransfer.updateBalanceAtNow(self.balances[address(0x8342DD495b3aE442BB3615f4779D6db0E85eBD48)], 750000e18);

        //update the total suppply
        self.uintVars[keccak256("total_supply")] += 7500000e18; //6th miner to allow for dispute
        //set Constants
        self.uintVars[keccak256("decimals")] = 18;
        self.uintVars[keccak256("targetMiners")] = 200;
        self.uintVars[keccak256("stakeAmount")] = 1000e18;
        self.uintVars[keccak256("disputeFee")] = 970e18;
        self.uintVars[keccak256("timeTarget")] = 180;
        self.uintVars[keccak256("timeOfLastNewValue")] = now - (now % self.uintVars[keccak256("timeTarget")]);
        self.uintVars[keccak256("difficulty")] = 1;
        self.uintVars[keccak256("height")] = 0;
    }

    /**
    * @dev This function allows stakers to request to withdraw their stake (no longer stake)
    * once they lock for withdraw(stakes.currentStatus = 2) they are locked for 7 days before they
    * can withdraw the deposit
    */
    function requestStakingWithdraw(BerryStorage.BerryStorageStruct storage self) public {
        BerryStorage.StakeInfo storage stakes = self.stakerDetails[msg.sender];
        //Require that the miner is staked
        require(stakes.currentStatus == 1, "Miner is not staked");

        //Change the miner staked to locked to be withdrawStake
        stakes.currentStatus = 2;

        //Change the startDate to now since the lock up period begins now
        //and the miner can only withdraw 7 days later from now(check the withdraw function)
        stakes.startDate = now - (now % 86400);

        //Reduce the staker count
        self.uintVars[keccak256("stakerCount")] -= 1;

        //Update the minimum dispute fee that is based on the number of stakers 
        BerryDispute.updateMinDisputeFee(self);
        emit StakeWithdrawRequested(msg.sender);
    }

    /**
    * @dev This function allows users to withdraw their stake after a 7 day waiting period from request
    */
    function withdrawStake(BerryStorage.BerryStorageStruct storage self) public {
        BerryStorage.StakeInfo storage stakes = self.stakerDetails[msg.sender];
        //Require the staker has locked for withdraw(currentStatus ==2) and that 7 days have
        //passed by since they locked for withdraw
        require(now - (now % 86400) - stakes.startDate >= 7 days, "7 days didn't pass");
        require(stakes.currentStatus == 2, "Miner was not locked for withdrawal");
        stakes.currentStatus = 0;
        emit StakeWithdrawn(msg.sender);
    }

    /**
    * @dev This function allows miners to deposit their stake.
    */
    function depositStake(BerryStorage.BerryStorageStruct storage self) public {
        newStake(self, msg.sender);
        //self adjusting disputeFee
        BerryDispute.updateMinDisputeFee(self);
    }

    /**
    * @dev This function is used by the init function to succesfully stake the initial 5 miners.
    * The function updates their status/state and status start date so they are locked it so they can't withdraw
    * and updates the number of stakers in the system.
    */
    function newStake(BerryStorage.BerryStorageStruct storage self, address staker) internal {
        require(BerryTransfer.balanceOf(self, staker) >= self.uintVars[keccak256("stakeAmount")], "Balance is lower than stake amount");
        //Ensure they can only stake if they are not currrently staked or if their stake time frame has ended
        //and they are currently locked for witdhraw
        require(self.stakerDetails[staker].currentStatus == 0 || self.stakerDetails[staker].currentStatus == 2, "Miner is in the wrong state");
        self.uintVars[keccak256("stakerCount")] += 1;
        self.stakerDetails[staker] = BerryStorage.StakeInfo({
            currentStatus: 1, //this resets their stake start date to today
            startDate: now - (now % 86400)
        });
        emit NewStake(staker);
    }

    /**
    * @dev Getter function for the requestId being mined 
    * @return variables for the current minin event: Challenge, 5 RequestId, difficulty and Totaltips
    */
    function getNewCurrentVariables(BerryStorage.BerryStorageStruct storage self) internal view returns(bytes32 _challenge,uint[5] memory _requestIds,uint256 _difficulty, uint256 _tip){
        for(uint i=0;i<5;i++){
            _requestIds[i] =  self.currentMiners[i].value;
        }
        return (self.currentChallenge,_requestIds,self.uintVars[keccak256("difficulty")],self.uintVars[keccak256("currentTotalTips")]);
    }

    /**
    * @dev Getter function for next requestId on queue/request with highest payout at time the function is called
    * @return onDeck/info on top 5 requests(highest payout)-- RequestId, Totaltips
    */
    function getNewVariablesOnDeck(BerryStorage.BerryStorageStruct storage self) internal view returns (uint256[5] memory idsOnDeck, uint256[5] memory tipsOnDeck) {
        idsOnDeck = getTopRequestIDs(self);
        for(uint i = 0;i<5;i++){
            tipsOnDeck[i] = self.requestDetails[idsOnDeck[i]].apiUintVars[keccak256("totalTip")];
        }
    }
    
    /**
    * @dev Getter function for the top 5 requests with highest payouts. This function is used within the getNewVariablesOnDeck function
    * @return uint256[5] is an array with the top 5(highest payout) _requestIds at the time the function is called
    */
    function getTopRequestIDs(BerryStorage.BerryStorageStruct storage self) internal view returns (uint256[5] memory _requestIds) {
        uint256[5] memory _max;
        uint256[5] memory _index;
        (_max, _index) = Utilities.getMax5(self.requestQ);
        for(uint i=0;i<5;i++){
            if(_max[i] != 0){
                _requestIds[i] = self.requestIdByRequestQIndex[_index[i]];
            }
            else{
                _requestIds[i] = self.currentMiners[4-i].value;
            }
        }
    }


   
}
