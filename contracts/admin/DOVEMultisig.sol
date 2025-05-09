// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IDOVEAdmin.sol";

/**
 * @title DOVE Multisig Governance
 * @dev Manages multi-signature approval for critical operations
 * Provides governance layer for the DOVE token ecosystem
 */
contract DOVEMultisig is ReentrancyGuard, AccessControl {
    // ================ Role Constants ================
    
    bytes32 public constant MULTISIG_ADMIN_ROLE = keccak256("MULTISIG_ADMIN_ROLE");
    bytes32 public constant APPROVER_ROLE = keccak256("APPROVER_ROLE");
    
    // ================ State Variables ================
    
    // Multisig configuration
    uint256 private _requiredApprovals;
    uint256 private _operationNonce;
    mapping(bytes32 => uint256) private _roleCount;
    
    // Operation tracking
    struct Operation {
        bytes callData;
        address target;
        bool executed;
        uint256 approvalCount;
        string description;
        uint256 creationTime;
    }
    
    mapping(bytes32 => Operation) private _operations;
    mapping(bytes32 => mapping(address => bool)) private _operationApprovals;
    
    // Confirmation timelock (24 hours)
    uint256 public constant CONFIRMATION_TIMELOCK = 24 hours;
    
    // ================ Events ================
    
    event OperationProposed(bytes32 indexed operationId, address indexed proposer, string description);
    event OperationApproved(bytes32 indexed operationId, address indexed approver);
    event OperationExecuted(bytes32 indexed operationId, address indexed executor);
    event OperationCancelled(bytes32 indexed operationId, address indexed canceller);
    event RequiredApprovalsChanged(uint256 oldValue, uint256 newValue);
    
    // ================ Constructor ================
    
    /**
     * @dev Constructor initializes the DOVE Multisig contract
     * @param initialAdmin Initial admin address
     * @param initialApprovers List of initial approvers
     * @param requiredSignatures Number of required signatures (must be <= initialApprovers.length)
     */
    constructor(
        address initialAdmin,
        address[] memory initialApprovers,
        uint256 requiredSignatures
    ) {
        require(initialAdmin != address(0), "Admin cannot be zero address");
        require(initialApprovers.length > 0, "Must provide at least one approver");
        require(
            requiredSignatures > 0 && requiredSignatures <= initialApprovers.length,
            "Required sigs must be > 0 and <= approver count"
        );
        
        // Set up roles
        _setupRole(MULTISIG_ADMIN_ROLE, initialAdmin);
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        
        // Add all initial approvers
        for (uint256 i = 0; i < initialApprovers.length; ) {
            require(initialApprovers[i] != address(0), "Approver cannot be zero address");
            _grantRole(APPROVER_ROLE, initialApprovers[i]);
            unchecked { ++i; }
        }
        
        _roleCount[APPROVER_ROLE] = initialApprovers.length;
        _requiredApprovals = requiredSignatures;
    }
    
    // ================ External Functions ================
    
    /**
     * @dev Propose a new operation
     * @param target Target contract address
     * @param callData Function call data
     * @param description Human-readable description of the operation
     * @return operationId The unique ID of the proposed operation
     */
    function proposeOperation(
        address target,
        bytes calldata callData,
        string calldata description
    ) external nonReentrant onlyRole(APPROVER_ROLE) returns (bytes32 operationId) {
        require(target != address(0), "Target cannot be zero address");
        require(callData.length > 0, "Call data cannot be empty");
        
        // Generate unique operation ID
        operationId = keccak256(
            abi.encodePacked(
                target,
                callData,
                _operationNonce++,
                block.timestamp
            )
        );
        
        // Store the operation
        _operations[operationId] = Operation({
            callData: callData,
            target: target,
            executed: false,
            approvalCount: 1, // Proposer automatically approves
            description: description,
            creationTime: block.timestamp
        });
        
        // Record proposer's approval
        _operationApprovals[operationId][msg.sender] = true;
        
        emit OperationProposed(operationId, msg.sender, description);
        emit OperationApproved(operationId, msg.sender);
        
        return operationId;
    }
    
    /**
     * @dev Approve an existing operation
     * @param operationId Operation ID to approve
     */
    function approveOperation(bytes32 operationId) external nonReentrant onlyRole(APPROVER_ROLE) {
        require(_operations[operationId].target != address(0), "Operation does not exist");
        require(!_operations[operationId].executed, "Operation already executed");
        require(!_operationApprovals[operationId][msg.sender], "Already approved");
        
        // Record approval
        _operationApprovals[operationId][msg.sender] = true;
        _operations[operationId].approvalCount++;
        
        emit OperationApproved(operationId, msg.sender);
    }
    
    /**
     * @dev Execute an approved operation
     * @param operationId Operation ID to execute
     * @return success Whether the execution was successful
     */
    function executeOperation(bytes32 operationId) external nonReentrant onlyRole(APPROVER_ROLE) returns (bool success) {
        Operation storage op = _operations[operationId];
        
        require(op.target != address(0), "Operation does not exist");
        require(!op.executed, "Operation already executed");
        require(op.approvalCount >= _requiredApprovals, "Not enough approvals");
        require(
            block.timestamp >= op.creationTime + CONFIRMATION_TIMELOCK,
            "Confirmation timelock not elapsed"
        );
        
        // Mark as executed before calling to prevent reentrancy
        op.executed = true;
        
        // Execute the call
        (success, ) = op.target.call(op.callData);
        require(success, "Operation execution failed");
        
        emit OperationExecuted(operationId, msg.sender);
        
        return success;
    }
    
    /**
     * @dev Cancel a pending operation
     * @param operationId Operation ID to cancel
     */
    function cancelOperation(bytes32 operationId) external nonReentrant {
        Operation storage op = _operations[operationId];
        
        require(op.target != address(0), "Operation does not exist");
        require(!op.executed, "Operation already executed");
        
        // Only the original proposer or an admin can cancel
        require(
            _operationApprovals[operationId][msg.sender] || hasRole(MULTISIG_ADMIN_ROLE, msg.sender),
            "Not authorized to cancel"
        );
        
        // Delete operation data
        delete _operations[operationId];
        
        emit OperationCancelled(operationId, msg.sender);
    }
    
    /**
     * @dev Change the number of required approvals
     * @param newRequiredApprovals New number of required approvals
     */
    function setRequiredApprovals(uint256 newRequiredApprovals) external nonReentrant onlyRole(MULTISIG_ADMIN_ROLE) {
        require(newRequiredApprovals > 0, "Required approvals must be > 0");
        require(
            newRequiredApprovals <= _roleCount[APPROVER_ROLE],
            "Required approvals cannot exceed approver count"
        );
        
        uint256 oldValue = _requiredApprovals;
        _requiredApprovals = newRequiredApprovals;
        
        emit RequiredApprovalsChanged(oldValue, newRequiredApprovals);
    }
    
    /**
     * @dev Add a new approver
     * @param approver Address of the new approver
     */
    function addApprover(address approver) external nonReentrant onlyRole(MULTISIG_ADMIN_ROLE) {
        require(approver != address(0), "Approver cannot be zero address");
        require(!hasRole(APPROVER_ROLE, approver), "Already an approver");
        
        _grantRole(APPROVER_ROLE, approver);
        _roleCount[APPROVER_ROLE]++;
    }
    
    /**
     * @dev Remove an existing approver
     * @param approver Address of the approver to remove
     */
    function removeApprover(address approver) external nonReentrant onlyRole(MULTISIG_ADMIN_ROLE) {
        require(hasRole(APPROVER_ROLE, approver), "Not an approver");
        require(
            _roleCount[APPROVER_ROLE] > _requiredApprovals,
            "Cannot reduce approvers below required approvals"
        );
        
        _revokeRole(APPROVER_ROLE, approver);
        _roleCount[APPROVER_ROLE]--;
    }
    
    // ================ View Functions ================
    
    /**
     * @dev Get details about an operation
     * @param operationId Operation ID
     * @return target Target address
     * @return approvalCount Number of approvals
     * @return executed Whether the operation was executed
     * @return creationTime When the operation was created
     * @return description Human-readable description
     */
    function getOperation(bytes32 operationId) external view returns (
        address target,
        uint256 approvalCount,
        bool executed,
        uint256 creationTime,
        string memory description
    ) {
        Operation storage op = _operations[operationId];
        return (
            op.target,
            op.approvalCount,
            op.executed,
            op.creationTime,
            op.description
        );
    }
    
    /**
     * @dev Check if an address has approved an operation
     * @param operationId Operation ID
     * @param approver Address to check
     * @return True if the address has approved the operation
     */
    function hasApproved(bytes32 operationId, address approver) external view returns (bool) {
        return _operationApprovals[operationId][approver];
    }
    
    /**
     * @dev Get the number of required approvals
     * @return Number of required approvals
     */
    function getRequiredApprovals() external view returns (uint256) {
        return _requiredApprovals;
    }
    
    /**
     * @dev Get approver count
     * @return Number of approvers
     */
    function getApproverCount() external view returns (uint256) {
        return _roleCount[APPROVER_ROLE];
    }
    
    /**
     * @dev Custom implementation to track role member count
     * @param role Role to check
     * @return Number of members with the role
     */
    function getRoleMemberCount(bytes32 role) public view returns (uint256) {
        return _roleCount[role];
    }
    
    /**
     * @dev Override the grantRole function to update the role count
     * @param role Role to grant
     * @param account Account to grant the role to
     */
    function grantRole(bytes32 role, address account) public override onlyRole(getRoleAdmin(role)) {
        if (!hasRole(role, account)) {
            _roleCount[role]++;
        }
        _grantRole(role, account);
    }
    
    /**
     * @dev Override the revokeRole function to update the role count
     * @param role Role to revoke
     * @param account Account to revoke the role from
     */
    function revokeRole(bytes32 role, address account) public override onlyRole(getRoleAdmin(role)) {
        if (hasRole(role, account)) {
            _roleCount[role]--;
        }
        _revokeRole(role, account);
    }
}
