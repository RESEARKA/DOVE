// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./DOVEFeatureController.sol";
import "../interfaces/IDOVEAdmin.sol";

/**
 * @title DOVE Admin
 * @dev Main administration contract for DOVE token
 */
contract DOVEAdmin is DOVEFeatureController, IDOVEAdmin {
    /**
     * @dev Constructor initializes the admin contract
     * @param feeManagerAddress Address of the fee manager contract
     */
    constructor(address feeManagerAddress) DOVEAdminBase(feeManagerAddress) {}
    
    // ================ External View Functions ================
    
    /**
     * @dev Check if token is paused
     * @return True if token is paused
     */
    function isPaused() external view override returns (bool) {
        return paused();
    }
    
    /**
     * @dev Check if token is launched
     * @return True if token is launched
     */
    function isLaunched() external view override returns (bool) {
        return _isTokenLaunched;
    }
    
    /**
     * @dev Get the launch timestamp
     * @return Launch timestamp, 0 if not launched
     */
    function getLaunchTimestamp() external view override returns (uint256) {
        return _launchTimestamp;
    }
    
    /**
     * @dev Check if maximum transaction limit is enabled
     * @return True if maximum transaction limit is enabled
     */
    function isMaxTxLimitEnabled() external view override returns (bool) {
        return _isMaxTxLimitEnabled;
    }
    
    /**
     * @dev Get the number of required approvals for multi-signature operations
     * @return Number of required approvals
     */
    function getRequiredApprovals() external view override returns (uint256) {
        return _requiredApprovals;
    }
    
    /**
     * @dev Get the list of approvers for multi-signature operations
     * @return Array of approver addresses
     */
    function getApprovers() external view override returns (address[] memory) {
        return _approvers;
    }
    
    /**
     * @dev Check if an operation has been approved by a specific account
     * @param operation Operation to check
     * @param account Account to check
     * @return True if the operation has been approved by the account
     */
    function hasApproved(bytes32 operation, address account) external view override returns (bool) {
        return _pendingApprovals[operation][account];
    }
    
    /**
     * @dev Get the number of approvals for an operation
     * @param operation Operation to check
     * @return Number of approvals
     */
    function getApprovalCount(bytes32 operation) external view override returns (uint256) {
        return _approvalCounts[operation];
    }
    
    /**
     * @dev Check if an operation has been completed
     * @param operation Operation to check
     * @return True if the operation has been completed
     */
    function isOperationComplete(bytes32 operation) external view override returns (bool) {
        return _operationComplete[operation];
    }
    
    /**
     * @dev Get the fee manager address
     * @return Fee manager address
     */
    function getFeeManager() external view override returns (address) {
        return address(_feeManager);
    }
}
