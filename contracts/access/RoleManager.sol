// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../utils/StringUtils.sol";

/**
 * @title RoleManager
 * @dev Manages role-based access control with time-limited approvals
 */
abstract contract RoleManager is AccessControl, ReentrancyGuard {
    // ================ Events ================
    
    event RoleOperationPending(bytes32 indexed role, address indexed account, bytes32 operation, uint256 approvals, uint256 required);
    event RoleOperationApproved(bytes32 indexed role, address indexed account, bytes32 operation, uint256 approvals, uint256 required);
    event RoleOperationExecuted(bytes32 indexed role, address indexed account, bytes32 operation);
    event RoleOperationExpired(bytes32 indexed role, address indexed account, bytes32 operation);
    event RequiredRoleApprovalsUpdated(uint256 oldRequired, uint256 newRequired);
    
    // ================ Constants ================
    
    // Role approval expiration - approvals automatically expire after this time
    uint256 internal constant ROLE_APPROVAL_EXPIRATION = 3 days;
    
    // ================ State Variables ================
    
    // Multi-signature role management
    uint256 internal _requiredRoleApprovals = 3;  // Default: require 3 admins
    mapping(bytes32 => mapping(address => bool)) internal _roleChangeApprovals;
    mapping(bytes32 => uint256) internal _roleChangeApprovalCounts;
    mapping(bytes32 => uint256) internal _roleChangeInitiatedTime;
    
    // Core roles
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant ROLE_MANAGER_ROLE = keccak256("ROLE_MANAGER_ROLE");
    
    /**
     * @dev Override of grantRole to add multi-signature requirement
     * @param role Role to grant
     * @param account Account to receive role
     */
    function grantRole(bytes32 role, address account) public override nonReentrant {
        // Only role managers or admin role can grant roles
        require(hasRole(ROLE_MANAGER_ROLE, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), 
            "Must have role manager or admin role");
        
        // Create unique operation ID for this role grant
        bytes32 operation = keccak256(abi.encodePacked("grantRole", role, account));
        
        // Check if this role grant is already approved
        if (_processRoleChangeApproval(role, account, operation)) {
            // If enough approvals, grant the role
            _grantRole(role, account);
            emit RoleOperationExecuted(role, account, operation);
        }
    }
    
    /**
     * @dev Override of revokeRole to add multi-signature requirement
     * @param role Role to revoke
     * @param account Account to lose role
     */
    function revokeRole(bytes32 role, address account) public override nonReentrant {
        // Only role managers or admin role can revoke roles
        require(hasRole(ROLE_MANAGER_ROLE, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), 
            "Must have role manager or admin role");
        
        // Create unique operation ID for this role revocation
        bytes32 operation = keccak256(abi.encodePacked("revokeRole", role, account));
        
        // Check if this role revocation is already approved
        if (_processRoleChangeApproval(role, account, operation)) {
            // If enough approvals, revoke the role
            _revokeRole(role, account);
            emit RoleOperationExecuted(role, account, operation);
        }
    }
    
    /**
     * @dev Set the number of required approvals for role changes
     * @param requiredApprovals Number of required approvals
     */
    function setRequiredRoleApprovals(uint256 requiredApprovals) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(requiredApprovals > 0, "Required approvals must be positive");
        
        uint256 oldRequired = _requiredRoleApprovals;
        _requiredRoleApprovals = requiredApprovals;
        
        emit RequiredRoleApprovalsUpdated(oldRequired, requiredApprovals);
    }
    
    /**
     * @dev Approve a pending role change operation
     * @param operation Unique operation ID
     */
    function approveRoleOperation(bytes32 operation) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!_roleChangeApprovals[operation][msg.sender], "Already approved this operation");
        
        // Check for operation timeout
        uint256 initiatedTime = _roleChangeInitiatedTime[operation];
        require(initiatedTime > 0, "Operation does not exist");
        require(block.timestamp < initiatedTime + ROLE_APPROVAL_EXPIRATION, "Operation expired");
        
        // Record approval
        _roleChangeApprovals[operation][msg.sender] = true;
        _roleChangeApprovalCounts[operation] += 1;
        
        emit RoleOperationApproved(bytes32(0), address(0), operation, _roleChangeApprovalCounts[operation], _requiredRoleApprovals);
    }
    
    /**
     * @dev Process a role change approval, returns true if enough approvals
     * @param role Role being changed
     * @param account Account affected by the change
     * @param operation Unique operation ID
     * @return True if the operation has enough approvals and can proceed
     */
    function _processRoleChangeApproval(bytes32 role, address account, bytes32 operation) internal returns (bool) {
        // If this is the first approval for this operation, record the time
        if (_roleChangeInitiatedTime[operation] == 0) {
            _roleChangeInitiatedTime[operation] = block.timestamp;
        } else {
            // Check for operation timeout
            if (block.timestamp >= _roleChangeInitiatedTime[operation] + ROLE_APPROVAL_EXPIRATION) {
                // Reset approval state on timeout and emit event
                _roleChangeApprovalCounts[operation] = 0;
                _roleChangeInitiatedTime[operation] = block.timestamp;
                
                emit RoleOperationExpired(role, account, operation);
            }
        }
        
        // Record this approval if not already recorded
        if (!_roleChangeApprovals[operation][msg.sender]) {
            _roleChangeApprovals[operation][msg.sender] = true;
            _roleChangeApprovalCounts[operation] += 1;
        }
        
        // Check if we have enough approvals
        if (_roleChangeApprovalCounts[operation] >= _requiredRoleApprovals) {
            // Reset approval state before proceeding with the change
            _roleChangeApprovalCounts[operation] = 0;
            
            return true;
        }
        
        // Not enough approvals yet, emit event and revert
        emit RoleOperationPending(role, account, operation, _roleChangeApprovalCounts[operation], _requiredRoleApprovals);
        revert(string(abi.encodePacked("Role operation requires ", 
            StringUtils.toString(_requiredRoleApprovals - _roleChangeApprovalCounts[operation]), " more approvals")));
    }
}
