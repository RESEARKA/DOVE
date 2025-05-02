// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IDOVEAdmin.sol";
import "./interfaces/IDOVE.sol";
import "./DOVEFees.sol";

/**
 * @title DOVE Admin Functions
 * @dev Implementation of admin functionality for DOVE token
 */
contract DOVEAdmin is Ownable2Step, Pausable, ReentrancyGuard, AccessControl, IDOVEAdmin {
    
    // ================ State Variables ================
    
    // Flag to control if max transaction limit is enabled
    bool private _isMaxTxLimitEnabled = true;
    
    // Fee management module
    DOVEFees private immutable _feeManager;
    
    // Multi-signature governance variables
    address[] private _approvers;
    mapping(address => bool) private _isApprover;
    mapping(address => uint256) private _approverIndices; // Store index of each approver for efficient removal
    uint256 private _requiredApprovals;
    mapping(bytes32 => uint256) private _approvalCounts;
    mapping(bytes32 => mapping(address => bool)) private _pendingApprovals;
    
    // ================ Modifiers ================
    
    /**
     * @dev Requires multi-signature approval for critical operations
     * @param operation The operation identifier (bytes32 hash)
     */
    modifier requiresMultiSig(bytes32 operation) {
        // Check if operation already has sufficient approvals
        if (_approvalCounts[operation] >= _requiredApprovals) {
            // SECURITY: Only reset approvals after successful execution
            // Store the current approval count to use in the event emission
            uint256 currentApprovals = _approvalCounts[operation];
            
            // Set a flag to indicate this operation is currently being executed
            // This prevents reentrancy attacks through the same operation
            bool isBeingExecuted = true;
            
            // Execute the function body
            _;
            
            // If we reach this point, the function body completed successfully
            // Now we can safely reset the approval state
            if (isBeingExecuted) {
                // SECURITY: Reset all approval tracking for this operation
                _approvalCounts[operation] = 0;
                
                // Clear all individual approver records for this operation
                for (uint256 i = 0; i < _approvers.length; i++) {
                    _pendingApprovals[operation][_approvers[i]] = false;
                }
                
                emit OperationExecuted(operation, currentApprovals);
            }
        } else {
            // If not enough approvals, record the approval and revert
            _pendingApprovals[operation][msg.sender] = true;
            _approvalCounts[operation] += 1;
            
            emit OperationPending(operation, msg.sender, _approvalCounts[operation], _requiredApprovals);
            revert(string(abi.encodePacked("Operation ", bytes32ToString(operation), " requires ", 
                toString(_requiredApprovals - _approvalCounts[operation]), " more approvals")));
        }
    }
    
    /**
     * @dev Helper function to convert bytes32 to string for better error messages
     * @param data The bytes32 to convert
     * @return string representation
     */
    function bytes32ToString(bytes32 data) internal pure returns (string memory) {
        bytes memory bytesString = new bytes(64);
        for (uint256 i = 0; i < 32; i++) {
            bytes1 char = bytes1(bytes32(uint256(data) * 2 ** (8 * i)));
            bytesString[i*2] = bytes1(uint8(char) / 16 + (uint8(char) / 16 > 9 ? 87 : 48));
            bytesString[i*2+1] = bytes1(uint8(char) % 16 + (uint8(char) % 16 > 9 ? 87 : 48));
        }
        return string(bytesString);
    }
    
    /**
     * @dev Helper function to convert uint to string for better error messages
     * @param value The uint to convert
     * @return string representation
     */
    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        
        uint256 temp = value;
        uint256 digits;
        
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        
        bytes memory buffer = new bytes(digits);
        
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        
        return string(buffer);
    }
    
    // ================ Constructor ================
    
    /**
     * @dev Constructor initializes admin module with fee manager
     * @param feeManager Address of the DOVEFees contract
     */
    constructor(DOVEFees feeManager) {
        require(address(feeManager) != address(0), "Fee manager cannot be zero address");
        _feeManager = feeManager;
        
        // Initialize multi-signature with owner as first approver
        _approvers.push(msg.sender);
        _isApprover[msg.sender] = true;
        _approverIndices[msg.sender] = 0; // Store the index
        _requiredApprovals = 1; // Start with 1 required approval (owner only)
        
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    // ================ Multi-Signature Management ================
    
    /**
     * @dev Add a new approver for multi-signature governance
     * @param approver Address of the new approver
     */
    function addApprover(address approver) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(approver != address(0), "Approver cannot be zero address");
        require(!_isApprover[approver], "Already an approver");
        
        _approvers.push(approver);
        _isApprover[approver] = true;
        _approverIndices[approver] = _approvers.length - 1; // Store the index
        
        emit ApproverAdded(approver);
    }
    
    /**
     * @dev Remove an approver from multi-signature governance
     * @param approver Address of the approver to remove
     */
    function removeApprover(address approver) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_isApprover[approver], "Not an approver");
        // SECURITY: Ensure we maintain enough approvers for the required threshold
        require(_approvers.length - 1 >= _requiredApprovals, "Cannot remove: would break multi-sig threshold");
        
        // Get the index of the approver to remove
        uint256 index = _approverIndices[approver];
        
        // Get the address of the last approver
        address lastApprover = _approvers[_approvers.length - 1];
        
        // Replace the removed approver with the last one
        _approvers[index] = lastApprover;
        _approverIndices[lastApprover] = index; // Update the index of the moved approver
        
        // Remove the last element
        _approvers.pop();
        
        // Clear approver status and index
        _isApprover[approver] = false;
        delete _approverIndices[approver];
        
        emit ApproverRemoved(approver);
    }
    
    /**
     * @dev Set the number of required approvals for multi-signature operations
     * @param required Number of required approvals
     */
    function setRequiredApprovals(uint256 required) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(required > 0, "Required approvals must be greater than zero");
        require(required <= _approvers.length, "Required approvals cannot exceed number of approvers");
        
        _requiredApprovals = required;
        
        emit RequiredApprovalsUpdated(required);
    }
    
    /**
     * @dev Get the current list of approvers
     * @return Array of approver addresses
     */
    function getApprovers() external view returns (address[] memory) {
        return _approvers;
    }
    
    /**
     * @dev Get the number of required approvals
     * @return Number of required approvals
     */
    function getRequiredApprovals() external view returns (uint256) {
        return _requiredApprovals;
    }
    
    /**
     * @dev Check if an operation has been approved by a specific approver
     * @param operation Operation hash
     * @param approver Approver address
     * @return Whether the operation has been approved by the approver
     */
    function hasApproved(bytes32 operation, address approver) external view returns (bool) {
        return _pendingApprovals[operation][approver];
    }
    
    /**
     * @dev Get the number of approvals for an operation
     * @param operation Operation hash
     * @return Number of approvals
     */
    function getApprovalCount(bytes32 operation) external view returns (uint256) {
        return _approvalCounts[operation];
    }
    
    /**
     * @dev Reset all approvals for an operation
     * @param operation Operation hash
     */
    function resetApprovals(bytes32 operation) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _approvalCounts[operation] = 0;
        
        emit ApprovalsReset(operation);
    }
    
    /**
     * @dev Approve an operation
     * @param operation Operation hash
     */
    function approve(bytes32 operation) external nonReentrant {
        require(_isApprover[msg.sender], "Not an authorized approver");
        require(!_pendingApprovals[operation][msg.sender], "Already approved this operation");
        
        _pendingApprovals[operation][msg.sender] = true;
        _approvalCounts[operation] += 1;
        
        emit OperationApproved(operation, msg.sender, _approvalCounts[operation], _requiredApprovals);
    }
    
    // ================ External Functions ================
    
    /**
     * @dev See {IDOVEAdmin-launch}
     */
    function launch() external onlyRole(DEFAULT_ADMIN_ROLE) requiresMultiSig(keccak256("launch")) nonReentrant {
        require(!_feeManager.isLaunched(), "Token already launched");
        
        // SECURITY: Apply checks-effects-interactions pattern
        // Perform external call last after all validations
        _feeManager.setLaunched(block.timestamp);
        emit TokenLaunched(block.timestamp);
    }
    
    /**
     * @dev See {IDOVEAdmin-pause}
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) requiresMultiSig(keccak256("pause")) nonReentrant {
        _pause();
    }
    
    /**
     * @dev See {IDOVEAdmin-unpause}
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) requiresMultiSig(keccak256("unpause")) nonReentrant {
        _unpause();
    }
    
    /**
     * @dev See {IDOVEAdmin-setDexStatus}
     */
    function setDexStatus(address dexAddress, bool isDex) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(dexAddress != address(0), "Cannot set zero address");
        _feeManager.setKnownDex(dexAddress, isDex);
        emit KnownDexUpdated(dexAddress, isDex);
    }
    
    /**
     * @dev See {IDOVEAdmin-excludeFromFee}
     */
    function excludeFromFee(address account, bool excluded) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(account != address(0), "Cannot exclude zero address");
        _feeManager.setExcludedFromFee(account, excluded);
        emit ExcludedFromFeeUpdated(account, excluded);
    }
    
    /**
     * @dev See {IDOVEAdmin-updateCharityWallet}
     */
    function updateCharityWallet(address newCharityWallet) external onlyRole(DEFAULT_ADMIN_ROLE) requiresMultiSig(keccak256("updateCharityWallet")) nonReentrant {
        require(newCharityWallet != address(0), "New charity wallet cannot be zero address");
        
        // SECURITY: Apply checks-effects-interactions pattern
        // Get current state before making any changes or external calls
        address oldWallet = _feeManager.getCharityWallet();
        
        // External call comes last
        _feeManager.updateCharityWallet(newCharityWallet);
        emit CharityWalletUpdated(oldWallet, newCharityWallet);
    }
    
    /**
     * @dev See {IDOVEAdmin-updateTaxRateDurations}
     */
    function updateTaxRateDurations(
        uint256 day1,
        uint256 day2,
        uint256 day3
    ) external onlyRole(DEFAULT_ADMIN_ROLE) requiresMultiSig(keccak256(abi.encodePacked("updateTaxRateDurations", day1, day2, day3))) nonReentrant {
        // SECURITY: Apply checks-effects-interactions pattern
        // External call comes last
        _feeManager.updateTaxRateDurations(day1, day2, day3);
        emit TaxRateDurationsUpdated(day1, day2, day3);
    }
    
    /**
     * @dev See {IDOVEAdmin-disableEarlySellTax}
     */
    function disableEarlySellTax() external onlyRole(DEFAULT_ADMIN_ROLE) requiresMultiSig(keccak256("disableEarlySellTax")) nonReentrant {
        // SECURITY: Apply checks-effects-interactions pattern
        // External call comes last
        _feeManager.disableEarlySellTax();
        emit EarlySellTaxDisabled();
    }
    
    /**
     * @dev See {IDOVEAdmin-disableMaxTxLimit}
     */
    function disableMaxTxLimit() external onlyRole(DEFAULT_ADMIN_ROLE) requiresMultiSig(keccak256("disableMaxTxLimit")) nonReentrant {
        // Update local state first
        _isMaxTxLimitEnabled = false;
        
        // Then emit events
        emit MaxTxLimitDisabled();
    }
    
    /**
     * @dev See {IDOVEAdmin-isMaxTxLimitEnabled}
     */
    function isMaxTxLimitEnabled() external view returns (bool) {
        return _isMaxTxLimitEnabled;
    }
    
    // ================ Events ================
    
    event ApproverAdded(address indexed approver);
    event ApproverRemoved(address indexed approver);
    event RequiredApprovalsUpdated(uint256 required);
    event OperationPending(bytes32 indexed operation, address indexed approver, uint256 currentApprovals, uint256 requiredApprovals);
    event OperationApproved(bytes32 indexed operation, address indexed approver, uint256 currentApprovals, uint256 requiredApprovals);
    event OperationExecuted(bytes32 indexed operation, uint256 approvalCount);
    event ApprovalsReset(bytes32 indexed operation);
}
