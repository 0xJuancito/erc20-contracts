pragma solidity ^0.5.16;

//import "./Manager.sol";
import "../Utils/Ownable.sol";
import "../interfaces/IManager.sol";

contract ManagerProxy is Ownable {
    IManager public manager;

    event NewManager(address indexed oldManager, address indexed newManager);

    modifier CheckPermit(string memory permit) {
        require(manager.userPermits(msg.sender, permit), "no permit");
        _;
    }

    modifier CheckPermitsOr(string[] memory permits) {
        bool granted = false;
        for (uint i = 0; i < permits.length; i++) {
            if (manager.userPermits(msg.sender, permits[i])) {
                granted = true;
                break;
            }
        }

        require(granted, "no permit");
        _;
    }

    modifier CheckUserPermit(address user, string memory permit) {
        require(manager.userPermits(user, permit), "no permit");
        _;
    }

    modifier CheckPermitOrGuardian(string memory permit) {
        require(manager.guardian() == msg.sender || manager.userPermits(msg.sender, permit), "no permit");
        _;
    }

    modifier OutBlacklist(address account) {
        address[] memory addArr = new address[](1);
        addArr[0] = account;
        require(!manager.inBlacklist(addArr), "account is in blacklist");
        _;
    }

    modifier OutBlacklist2(address account0, address account1) {
        address[] memory addArr = new address[](2);
        addArr[0] = account0;
        addArr[1] = account1;
        require(!manager.inBlacklist(addArr), "account is in blacklist");
        _;
    }

    modifier OutBlacklist3(address account0, address account1, address account2) {
        address[] memory addArr = new address[](3);
        addArr[0] = account0;
        addArr[1] = account1;
        addArr[2] = account2;
        require(!manager.inBlacklist(addArr), "account is in blacklist");
        _;
    }

    modifier ValidUDSDState() {
        require(!manager.dusdPaused(), "DUSD is paused");
        _;
    }

    modifier ValidDMTState() {
        require(!manager.dmtPaused(), "DMT is paused");
        _;
    }

    function setManager(address _manager) external onlyOwner {
        return _setManagerInternal(_manager);
    }

    function _getComptroller() internal view returns(address) {
        return manager.members("comptroller");
    }

    function _getIncome() internal view returns(address) {
        return manager.members("income");
    }

    function _getIncomeCache() internal view returns(address) {
        return manager.members("incomeCache");
    }

    function _getLiquidateFeeSwap() internal view returns(address) {
        return manager.members("liquidateSwap");
    }

    function _getReservedAssetSwap() internal view returns(address) {
        return manager.members("reservedSwap");
    }

    function _getDMT() internal view returns(address) {
        return manager.members("DMT");
    }

    function _getDUSD() internal view returns(address) {
        return manager.members("DUSD");
    }

    function _getDAOPool() internal view returns(address) {
        return manager.members("DAOPool");
    }

    function _getTreasury() internal view returns(address) {
        return manager.members("treasury");
    }

    // with decimal 18
    function _getRedeemTreasuryPercent() internal view returns(uint) {
        return manager.values("redeemTreasuryPercent");
    }

    // with decimal 18
    function _getReserveDAOPercent() internal view returns(uint) {
        return manager.values("reserveDAOPercent");
    }

    // with decimal 18
    function _getDUSDInterestDAOPercent() internal view returns(uint) {
        return manager.values("dusdInterestDAOPercent");
    }

    // with decimal 18
    function _getDUSDInflationDAOPercent() internal view returns(uint) {
        return manager.values("dusdInflationDAOPercent");
    }

    // with decimal 18
    function _getDUSDMintRate() internal view returns(uint) {
        return manager.values("dusdMintRate");
    }

    // with decimal 18
    function _getLiquidateFeePercent() internal view returns(uint) {
        return manager.values("liquidateFeePercent");
    }

    // with decimal 18
    function _getLiquidateFeeDAOPercent() internal view returns(uint) {
        return manager.values("liquidateFeeDAOPercent");
    }

    function _setManagerInternal(address _manager) internal {
        address oldManager = address(manager);
        manager = IManager(_manager);
        emit NewManager(oldManager, _manager);
    }

}
