// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IUniswapFactory.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

///@notice The standard ERC20 contract, with the exception of _balances being internal as opposed to private
import "./ERC20.sol";
import "./interfaces/IHexagonMarketplace.sol";


contract Honey is ERC20, Ownable, Pausable {

    // The constant used to calculate percentages, allows percentages to have 1 decimal place (ie 15.5%)
    uint constant BASIS_POINTS = 1000;

    // Variables related to fees and restrictions
    mapping(address => bool) excludedFromTransferRestrictions;
    mapping(address => bool) excludedFromTax;
    mapping(address => bool) taxableRecipient;

    mapping(address => uint) maxInitialPurchasePerWallet;

    struct collectionOwner {
        address collectionAddress;
        uint tokensSold;
    }
   
    ///@notice mapping that keeps tract of collection owners, offering them less sales tax for selling tokens recieved from royalties
    mapping(address => collectionOwner) collectionOwners;

    //collection owners pay 2.5% sales tax on royalties sold
    uint constant collectionOwnersSalesTax = 25;

    //Addresses that can update the collection owners parameters, so it can be done on request by the owners by a trusted wallet
    mapping(address => bool) verifiedAddresses;

    // Windows of time at the start of launch, during which this token has special trading restrictions
    uint specialTimePeriod;
    uint hourAfterLaunch;

    ///@notice this is the sales tax, initially set to 15% (150 / BASIS_POINTS = 0.15);
    uint public salesTax = 150;
    uint constant maxSalesTax = 150;

    IHexagonMarketplace hexagonMarketplace;

    address public distributionContract;
    
    constructor() ERC20("HONEY", "HNY") {

        _mint(msg.sender, 1000000 ether);
        
        // ///@notice get the sushiswap router on polygon
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);

        // // Create a uniswap pair for this new token
        address uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());
        
        // Allow the deployer and liquidity pool to trade tokens freely in the first 6 days
        excludedFromTransferRestrictions[msg.sender] = true;
        excludedFromTransferRestrictions[uniswapV2Pair] = true;
        excludedFromTransferRestrictions[0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506] = true;

        // Set deployer and this address as free from tax as free from tax, other addresses will be added to this exclusion whitelist
        excludedFromTax[msg.sender] = true;
        excludedFromTax[address(this)] = true;

        // Sets the liquidity pairing to be taxable on selling of tokens, more liquidity pools could be added
        taxableRecipient[uniswapV2Pair] = true;
       
    }

    /**
    *@dev Override ERC20 transfer function to prevent trading when paused
    */
    function transfer(address recipient, uint256 amount) public override whenNotPaused returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
     

    /**
    *@dev Override ERC20 transferFrom function to prevent trading when paused
    */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override whenNotPaused  returns (bool) {
        _spendAllowance(sender, _msgSender(), amount);
        _transfer(sender, recipient, amount);

        return true;
    }

    /**
    * @dev Transfer is adjusted to charge a sales tax when selling to set liquidity pools, this tax is sent to this address, with a portion being sold to the liquidity
    * pool for matic. These funds can be claimed ans set to the set protocal wallets
    *  There is some additonal logic adding limitations to sales, purchases and a different sales tax for the first 6 days this protocol is public, with additional 
    *  restrictions for the first hour. There restrictions aim to help smooth over the initial laucnh and prevent whales and bots from having an advantage 
    */
    function _transfer(address sender, address recipient, uint256 amount) internal override {

        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount should be greater than zero");

        _beforeTokenTransfer(sender, recipient, amount);

        uint feePercent = salesTax;

        // ///@notice check to see there is a sales tax applied by checking if the reciever is a liquidity pool, and if the sender is not excluded from paying taxes 
        bool toTax = (taxableRecipient[recipient] && !excludedFromTax[sender]);
       

        ///@notice check if the current time is within the time period that requires addtional logic
        if(block.timestamp < specialTimePeriod) {

            ///@notice if a liquidity pool in not invloved in any way, and the wallets involved with sending aren't exempt from the transfer restricitons
            ///then this shouldn't be allowed, and honey can be transfered to owher wallets at this time
            bool allowed = (taxableRecipient[recipient] || taxableRecipient[sender] || taxableRecipient[msg.sender] || excludedFromTransferRestrictions[recipient] ||
                excludedFromTransferRestrictions[sender] || excludedFromTransferRestrictions[msg.sender]); 

            ///@notice tokens are being traded to other wallets during the restricted time period
            require(allowed, "Can't trade to other wallets at the moment");
            

            ///@notice check to see if the sender or opperator is a taxable reciepient (liquidity pool), if so then someone is attempting to buy, which has some 
            ///restricitons at this time
            if(taxableRecipient[sender] || taxableRecipient[msg.sender]) {

                ///@notice tokens are being purchased so check if there are purchasing more than they are allowed
                uint maxPurchase = 100 ether;

                ///@notice additonal restrictions are applied for the first hour this protocal is live
                if(block.timestamp < hourAfterLaunch) {
                    maxPurchase = 20 ether;
                }

                //Check if purchased above allowed amount
                require(maxInitialPurchasePerWallet[recipient] + amount <= maxPurchase, "Max purchase Exceeded for this time");

                //Update purchases
                maxInitialPurchasePerWallet[recipient] += amount;


            } else if(toTax) {

                ///@notice this is a taxable sale, and during this tiome period the sales tax starts at 45% and decreases over time at a rate of 5% per day
                /// until it reaches the final sales tax of 15% (numbers are multiplied by 10 to allow an additional decimal point of expression)
                //TODO: double check this math
                feePercent = (((specialTimePeriod - block.timestamp) * 300) / 6 days) + feePercent;


            } 
            
        }
        
        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");

        unchecked {
            _balances[sender] = senderBalance  - (amount);
        }

        if(toTax) {

            uint tax;

            if(collectionOwners[sender].collectionAddress != address(0)) {

                ///@notice this address is tied to a collection on the hexagon marketplace, so they recieve a lower tax on royalties earned
                collectionOwner memory _collectionOwner = collectionOwners[sender];

                uint royaltiesEarned = hexagonMarketplace.getRoyaltiesGenerated(_collectionOwner.collectionAddress, 0);

                if(_collectionOwner.tokensSold + amount <= royaltiesEarned) {

                    // update the number of tokens sold using this tax
                    collectionOwners[sender].tokensSold += amount;

                    tax = (amount * collectionOwnersSalesTax) / BASIS_POINTS;

                } else {

                    ///@notice This address is trying to sell more tokens than earned from royalties on the collection, so give reduced tax on remaining royalties
                    uint amountWithReducedTax = royaltiesEarned - _collectionOwner.tokensSold;

                    uint toBetaxedInFull = amount - amountWithReducedTax;

                    // Tax in full the amount sold over whats earned in royalties
                    tax = (toBetaxedInFull * feePercent) / BASIS_POINTS;

                    // Tax up to the royalties earned with the reduced tax
                    tax += (amountWithReducedTax * collectionOwnersSalesTax) / BASIS_POINTS;

                    // update the number of tokens sold using this tax
                    collectionOwners[sender].tokensSold = royaltiesEarned;

                }


            } else {

                ///@notice this transaction will be taxed, so a potion of the tax will go to this contract, and another portion will be sold to the
                /// liquidity pool for matic 
                tax = ((amount * feePercent) / BASIS_POINTS);


            }

            amount -= tax;

            ///@notice set the total tax to the balance of this contract, some (or all) of the tax will be solid to matic
            _balances[distributionContract] += tax;

            emit Transfer(sender, distributionContract, tax);

            _balances[recipient] += amount;

            emit Transfer(sender, recipient, amount);


        } else {

            ///@notice no sales tax required, add balance normally
            _balances[recipient] = _balances[recipient] + (amount);

            emit Transfer(sender, recipient, amount);

        }

        _afterTokenTransfer(sender, recipient, amount);
            
    }

    /**
    * @dev gets the sales tax of the token when sold to a liquidity pool, returns based on BASIS_POINTS (1000)
    */
    function getSalesTax() external view returns (uint) {

        if(block.timestamp < specialTimePeriod) {
            return  (((specialTimePeriod - block.timestamp) * 300) / 6 days) + salesTax;
        } else {
            return salesTax;
        }

    }

    /**
    * @dev This allows the contract to revieve matic by selling honey to the liquidity pool
    */
    receive() external payable {}

    /**
    * @dev Sets the sales tax
    * Requires the caller to be the owner of the contract
    */
    function SetSalesTax(uint _salesTax) external onlyOwner {

        require(_salesTax <= maxSalesTax, "tax can't be above max tax");

        salesTax = _salesTax;

    }

    /**
    * @dev Sets an address to be able to transfer the token to other wallets
    * Requires the caller to be the owner of the contract
    */
    function ExcludeFromTransferRestrictions(address _address, bool _value) external onlyOwner {

        excludedFromTransferRestrictions[_address] = _value;

    }

    /**
    * @dev Sets an address to excluded from the sales tax
    * Requires the caller to be the owner of the contract
    */
    function ExcludeFromTax(address _address, bool _value) external onlyOwner {

        excludedFromTax[_address] = _value;

    }

    /**
    * @dev Sets an address to be taxable if tokens are sent to it (ie liquidity pools)
    * Requires the caller to be the owner of the contract
    */
    function setTaxableRecipient(address _address, bool _value) external onlyOwner {

        taxableRecipient[_address] = _value;

    }

    /**
    * @dev Sets the hexagon marketplace interface, which is used to check royalties collected on the marketplace
    * Requires the sender to the owner of the collection
    */
    function setHexagonMarketplace(address _hexagonAddress) external onlyOwner {

        require(_hexagonAddress != address(0), "Zero Address");

        hexagonMarketplace = IHexagonMarketplace(_hexagonAddress);

    }

    function setDistributionContract(address _distributioncontract) external onlyOwner {

        require(_distributioncontract != address(0), "Zero Address");

        distributionContract = _distributioncontract;

    }

    /**
    * @dev Adds an address that owns a collection traded on the hexagonMarketplace, so the address is charged a lower tax percent for the royalties earned,
    * or updates the payment address of a collection, removing the data for the pervious owner
    * Requires the sender to be a verified address
    */
    function updateWhitelistedCollection(address _collectionAddress, address _walletAddress, address _previousAddress) external {

        require(verifiedAddresses[msg.sender], "Needs to be called by a verified address");

        if(_previousAddress == address(0)) {

            collectionOwners[_walletAddress] = collectionOwner(_collectionAddress, 0);
            
        } else {

            collectionOwner memory previousCollectionOwner = collectionOwners[_previousAddress];

            require(previousCollectionOwner.collectionAddress != address(0), "Collection does not exist");

            collectionOwners[_walletAddress] = previousCollectionOwner;

            delete collectionOwners[_previousAddress];

        }

    }

    /**
    * @dev updates the addresses that are able to call the updateWhitelistedCollection function
    * Requires the caller to be the owner of the collection
    */
    function updateVerifiedAddresses(address _address, bool _value) external onlyOwner {

        require(_address != address(0), "Zero Address");

        verifiedAddresses[_address] = _value;
    }

    /**
    * @dev sets a time window with special restrictions
    * this can only be set once, and will be done on launch, called by the owners
    */
    function startTimePeriod() external onlyOwner {

        require(specialTimePeriod == 0, "Can only call once");

        // Setting the 6 day time period which has special restrictions to start on deployment
        specialTimePeriod = block.timestamp + (6 days);

        // Setting this to be a day and an hour after deployment, but planning to open things up 24 hours after deployment giving 1 hour of extra restrictions
        // on purchaseshelp things run smoothly
        hourAfterLaunch = block.timestamp + (1 hours);

    }

}