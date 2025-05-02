// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../utils/StringUtils.sol";

/**
 * @title MultiSigControl
 * @dev Implements multi-signature approval system for critical operations
 */
abstract contract MultiSigControl is AccessControl, ReentrancyGuard {
    // ================ Events ================
    
    event OperationPending(bytes32 indexed operation, address indexed approver, uint256 currentApprovals, uint256 requiredApprovals);
    event OperationApproved(bytes32 indexed operation, address indexed approver, uint256 currentApprovals, uint256 requiredApprovals);
    event OperationExecuted(bytes32 indexed operation, uint256 approvalCount);
    event ApprovalsReset(bytes32 indexed operation);
    event ApproverAdded(address indexed approver);
    event ApproverRemoved(address indexed approver);
    event RequiredApprovalsUpdated(uint256 oldRequired, uint256 newRequired);
    
    // ================ State Variables ================
    
    // Multi-signature requirement
    uint256 internal _requiredApprovals = 2;
    
    // List of approvers (for multi-signature governance)
    address[] internal _approvers;
    
    // Operation approval tracking
    mapping(bytes32 => mapping(address => bool)) internal _pendingApprovals;
    mapping(bytes32 => uint256) internal _approvalCounts;
    mapping(bytes32 => bool) internal _operationComplete;
    mapping(bytes32 => bool) internal _operationInProgress;
    
    /**
     * @dev Constructor - set up first approver
     */
    constructor() {
        // First approver is the deployer
        _approvers.push(msg.sender);
    }
    
    /**
     * @dev Requires multi-signature approval for critical operations
     * @param operation The operation identifier (bytes32 hash)
     */
    modifier requiresMultiSig(bytes32 operation) {
        // SECURITY: Prevent recursive calls to the same operation
        require(!_operationInProgress[operation], "Reentrant call detected");
        require(!_operationComplete[operation], "Operation already executed");
        
        // CHECKS: Verify if operation already has sufficient approvals
        uint256 currentApprovalCount = _approvalCounts[operation];
        bool hasEnoughApprovals = currentApprovalCount >= _requiredApprovals;
        
        if (!hasEnoughApprovals) {
            // If not enough approvals, record the approval and revert
            _pendingApprovals[operation][msg.sender] = true;
            _approvalCounts[operation] += 1;
            
            emit OperationPending(operation, msg.sender, _approvalCounts[operation], _requiredApprovals);
            revert(string(abi.encodePacked("Operation requires ", 
                StringUtils.toString(_requiredApprovals - _approvalCounts[operation]), " more approvals")));
        }
        
        // EFFECTS (BEFORE FUNCTION EXECUTION):
        // Mark operation as in progress to prevent reentrancy
        _operationInProgress[operation] = true;
        
        // Store approval count for event emission
        uint256 approvalCountForEvent = currentApprovalCount;
        
        // Reset all approval states before any external calls can occur
        // This ensures that even if reentrancy occurs, the operation can't be approved again
        _approvalCounts[operation] = 0;
        for (uint256 i = 0; i < _approvers.length; i++) {
            _pendingApprovals[operation][_approvers[i]] = false;
        }
        
        // INTERACTION: Execute the function body, which must be marked with nonReentrant
        _;
        
        // Post-execution effects - Mark complete ONLY after successful execution
        _operationComplete[operation] = true;
        
        // Emit event after successful execution
        emit OperationExecuted(operation, approvalCountForEvent);
        
        // Reset in-progress flag
        _operationInProgress[operation] = false;
    }
    
    /**
     * @dev Add a new approver for multi-signature operations
     * @param approver Address of the new approver
     */
    function addApprover(address approver) external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        require(approver != address(0), "Approver cannot be zero address");
        
        // Check if approver already exists
        bool alreadyAdded = false;
        for (uint256 i = 0; i < _approvers.length; i++) {
            if (_approvers[i] == approver) {
                alreadyAdded = true;
                break;
            }
        }
        
        require(!alreadyAdded, "Approver already exists");
        
        // Add the new approver
        _approvers.push(approver);
        
        emit ApproverAdded(approver);
    }
    
    /**
     * @dev Remove an approver from multi-signature operations
     * @param approver Address of the approver to remove
     */
    function removeApprover(address approver) external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_approvers.length > 1, "Cannot remove last approver");
        
        // Find and remove the approver
        bool found = false;
        for (uint256 i = 0; i < _approvers.length; i++) {
            if (_approvers[i] == approver) {
                // Replace with the last element and pop
                _approvers[i] = _approvers[_approvers.length - 1];
                _approvers.pop();
                found = true;
                break;
            }
        }
        
        require(found, "Approver not found");
        
        // If we now have fewer approvers than required, update required approvals
        if (_approvers.length < _requiredApprovals) {
            uint256 oldRequired = _requiredApprovals;
            _requiredApprovals = _approvers.length;
            emit RequiredApprovalsUpdated(oldRequired, _requiredApprovals);
        }
        
        emit ApproverRemoved(approver);
    }
    
    /**
     * @dev Set the number of required approvals for multi-signature operations
     * @param required Number of required approvals
     */
    function setRequiredApprovals(uint256 required) external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        require(required > 0, "Required approvals must be greater than 0");
        require(required <= _approvers.length, "Required approvals cannot exceed approvers");
        
        uint256 oldRequired = _requiredApprovals;
        _requiredApprovals = required;
        
        emit RequiredApprovalsUpdated(oldRequired, required);
    }
    
    /**
     * @dev Reset the approvals for an operation
     * @param operation Operation to reset approvals for
     */
    function resetApprovals(bytes32 operation) external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        // Check that operation exists (has at least one approval)
        require(_approvalCounts[operation] > 0, "Operation does not exist");
        
        // Reset all approvals for the operation
        _approvalCounts[operation] = 0;
        for (uint256 i = 0; i < _approvers.length; i++) {
            _pendingApprovals[operation][_approvers[i]] = false;
        }
        
        emit ApprovalsReset(operation);
    }
    
    /**
     * @dev Approve an operation
     * @param operation Operation to approve
     */
    function approveOperation(bytes32 operation) external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        // Check that operation is not complete
        require(!_operationComplete[operation], "Operation already executed");
        
        // Check that the sender has not already approved
        require(!_pendingApprovals[operation][msg.sender], "Already approved");
        
        // Record the approval
        _pendingApprovals[operation][msg.sender] = true;
        _approvalCounts[operation] += 1;
        
        emit OperationApproved(operation, msg.sender, _approvalCounts[operation], _requiredApprovals);
    }
}
