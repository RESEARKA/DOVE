// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./DOVEFeatureController.sol";
import "../interfaces/IDOVEAdmin.sol";

/**
 * @title DOVE Admin
 * @dev Main administration contract for DOVE token
 */
contract DOVEAdmin is DOVEFeatureController {
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
    function isPaused() external view returns (bool) {
        return paused();
    }
    
    /**
     * @dev Check if token is launched
     * @return True if token is launched
     */
    function isLaunched() external view returns (bool) {
        return _feeManager.isLaunched();
    }
    
    /**
     * @dev Get the timestamp when token was launched
     * @return Timestamp of token launch
     */
    function getLaunchTimestamp() external view returns (uint256) {
        return _feeManager.getLaunchTimestamp();
    }
    
    /**
     * @dev Get the required number of approvals for multi-sig operations
     * @return Required approval count
     */
    function getRequiredApprovals() external view returns (uint256) {
        return _requiredApprovals;
    }
    
    /**
     * @dev Get list of all approvers
     * @return Array of approver addresses
     */
    function getApprovers() external view returns (address[] memory) {
        return _approvers;
    }
    
    /**
     * @dev Check if an account has approved an operation
     * @param operation Hash of the operation
     * @param account Address to check
     * @return True if approved
     */
    function hasApproved(bytes32 operation, address account) external view returns (bool) {
        return _pendingApprovals[operation][account];
    }
    
    /**
     * @dev Get current approval count for an operation
     * @param operation Hash of the operation
     * @return Current approval count
     */
    function getApprovalCount(bytes32 operation) external view returns (uint256) {
        return _approvalCounts[operation];
    }
    
    /**
     * @dev Check if an operation is complete
     * @param operation Hash of the operation
     * @return True if completed
     */
    function isOperationComplete(bytes32 operation) external view returns (bool) {
        return _operationComplete[operation];
    }
    
    /**
     * @dev Get fee manager address
     * @return Fee manager contract address
     */
    function getFeeManager() external view returns (address) {
        return address(_feeManager);
    }
    
    /**
     * @dev Set DEX status for an address
     * @param dexAddress Address to set status for
     * @param isDex Whether the address is a DEX
     */
    function setDexStatus(address dexAddress, bool isDex) external override(DOVEFeatureController) {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Admin role required");
        _feeManager.setDexStatus(dexAddress, isDex);
    }
    
    /**
     * @dev Exclude or include an address from fees
     * @param account Address to update
     * @param excluded Whether to exclude from fees
     */
    function excludeFromFee(address account, bool excluded) external override(DOVEFeatureController) {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Admin role required");
        _feeManager.excludeFromFee(account, excluded);
    }
    
    /**
     * @dev Update tax rate durations
     * @param firstDayHours Hours for first tax rate
     * @param secondDayHours Hours for second tax rate
     * @param thirdDayHours Hours for third tax rate
     */
    function updateTaxRateDurations(
        uint256 firstDayHours,
        uint256 secondDayHours,
        uint256 thirdDayHours
    ) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Admin role required");
        _feeManager.updateTaxRateDurations(firstDayHours, secondDayHours, thirdDayHours);
    }
    
    // ======= Override functions to resolve inheritance conflicts =======
    
    /**
     * @notice Launches the token by calling the parent launch logic.
     * Overrides the base launch function to add specific admin requirements.
     */
    function launch() public override(DOVEFeatureController) onlyRole(DEFAULT_ADMIN_ROLE) requiresMultiSig(keccak256("launch")) nonReentrant {
        super.launch();
    }
    
    /**
     * @dev Check if max transaction limit is enabled
     */
    function isMaxTxLimitEnabled() external view returns (bool) {
        return _isMaxTxLimitEnabled;
    }
}
