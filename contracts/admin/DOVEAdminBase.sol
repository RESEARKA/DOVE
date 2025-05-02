// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IDOVEAdmin.sol";
import "../interfaces/IDOVEFees.sol";

/**
 * @title DOVE Admin Base
 * @dev Base contract for DOVE administration functionality
 */
abstract contract DOVEAdminBase is Ownable2Step, Pausable, ReentrancyGuard, AccessControl {
    // ================ State Variables ================
    
    // Fee management module - handles charity fee and early sell tax
    IDOVEFees internal _feeManager;
    
    // Token launch status
    bool internal _isTokenLaunched;
    uint256 internal _launchTimestamp;
    
    // Maximum transaction limit status
    bool internal _isMaxTxLimitEnabled = true;
    
    // Multi-signature requirement
    uint256 internal _requiredApprovals = 2;
    
    // List of approvers (for multi-signature governance)
    address[] internal _approvers;
    
    // Operation approval tracking
    mapping(bytes32 => mapping(address => bool)) internal _pendingApprovals;
    mapping(bytes32 => uint256) internal _approvalCounts;
    mapping(bytes32 => bool) internal _operationComplete;
    mapping(bytes32 => bool) internal _operationInProgress;
    
    // ================ Constructor ================
    
    /**
     * @dev Constructor initializes the admin contract
     * @param feeManagerAddress Address of the fee manager contract
     */
    constructor(address feeManagerAddress) {
        require(feeManagerAddress != address(0), "Fee manager cannot be zero address");
        
        // Initialize fee manager
        _feeManager = IDOVEFees(feeManagerAddress);
        
        // Grant DEFAULT_ADMIN_ROLE to deployer
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        
        // First approver is the deployer
        _approvers.push(msg.sender);
    }
    
    /**
     * @dev Helper for string conversion of bytes32
     * @param source Source bytes32 to convert
     */
    function bytes32ToString(bytes32 source) internal pure returns (string memory) {
        bytes memory bytesArray = new bytes(32);
        for (uint256 i; i < 32; i++) {
            bytesArray[i] = source[i];
        }
        return string(bytesArray);
    }
    
    /**
     * @dev Helper for uint256 conversion to string
     * @param value The uint256 to convert
     */
    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        
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
}
