pragma solidity 0.8.9;


 contract Ownable {
    address public owner;
    address public bridge;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event BridgeChanged(address indexed previousBridge, address indexed newBridge);

    constructor(address _owner,address _bridge)  {
        owner = _owner;
        bridge = _bridge;
    }
    

    modifier onlyOwner() {
        require(msg.sender == owner,"Only Owner can call this function");
        _;
    }
    modifier onlyBridge() {
        require(msg.sender == bridge, "only Bridge can call this function");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0),"new owner cannot be Address 0");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function changeBridge(address newBridgeAddress) public onlyOwner {
        require(newBridgeAddress != address(0),"new owner cannot be address 0");
        emit BridgeChanged(bridge, newBridgeAddress);
        bridge = newBridgeAddress;
    }
}