pragma solidity 0.8.17;

interface ISmartCoin {
    enum TransferStatus {
        Undefined,
        Created,
        Validated,
        Rejected
    }
    enum ApproveStatus {
        Undefined,
        Created,
        Validated,
        Rejected
    }
    struct TransferRequest {
        address from;
        address to;
        uint256 value;
        TransferStatus status;
        bool isTransferFrom;
        address spender;
    }
    struct ApproveRequest {
        address from;
        address to;
        uint256 value;
        ApproveStatus status;
    }

    event TransferRequested(
        bytes32 transferHash,
        address indexed from,
        address indexed to,
        address indexed spender,
        uint256 value
    );
    event TransferRejected(bytes32 transferHash);
    event TransferValidated(bytes32 transferHash);

    event ApproveRequested(
        bytes32 approveHash,
        address indexed from,
        address indexed to,
        uint256 value
    );
    event ApproveRejected(bytes32 approveHash);
    event ApproveValidated(bytes32 approveHash);

    function burn(uint256 amount) external returns (bool);

    function mint(address to, uint256 amount) external returns (bool);

    function recall(address from, uint256 amount) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function validateTransfer(bytes32 transferHash) external returns (bool);

    function rejectTransfer(bytes32 transferHash) external returns (bool);

    function balanceOf(address) external view returns (uint256);

    function engagedAmount(address addr) external view returns (uint256);

    function validateApprove(bytes32 approveHash) external returns (bool);

    function rejectApprove(bytes32 approveHash) external returns (bool);

    /* start performed by openzepplin ERC20 
     * function allowance(address owner, address spender)                            
     *        external                                                               
     *        view                                                                   
     *        returns (uint256);                                                     
     * function balanceOf(address) external view returns (uint256);                  
     * function totalSupply(address) external view returns (uint256);                
     * event Transfer(address indexed from, address indexed to, uint256 value);      
     * event Approval(                                                               
     *   address indexed owner,                                                      
     *   address indexed spender,                                                    
     *   uint256 value                                                               
     * );                                                                            
    end performed by openzepplin ERC20 */
}
