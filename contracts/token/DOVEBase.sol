// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IDOVEAdmin.sol";
import "../interfaces/IDOVEFees.sol";

/**
 * @title DOVE Base
 * @dev Base contract for DOVE token with core state variables and setup
 */
abstract contract DOVEBase is ERC20Permit, ReentrancyGuard, AccessControl {
    // ================ Constants ================
    
    // Base supply: 100 billion tokens with 18 decimals
    uint256 internal constant TOTAL_SUPPLY = 100_000_000_000 * 1e18;
    
    // Transaction limits
    uint256 internal constant MAX_TX_INITIAL = TOTAL_SUPPLY * 2 / 1000; // 0.2%
    uint256 internal constant MAX_TX_AFTER_24H = TOTAL_SUPPLY * 5 / 1000; // 0.5%
    
    // ================ Roles ================
    
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant ROLE_MANAGER_ROLE = keccak256("ROLE_MANAGER_ROLE");
    
    // Role approval expiration - approvals automatically expire after this time
    uint256 internal constant ROLE_APPROVAL_EXPIRATION = 3 days;
    
    // ================ State Variables ================
    
    // Fee management module - handles charity fee and early sell tax
    IDOVEFees public immutable feeManager;
    
    // Admin functionality module - handles owner controls
    IDOVEAdmin public immutable adminManager;
    
    // Multi-signature role management
    uint256 internal _requiredRoleApprovals = 3;  // Default: require 3 admins
    mapping(bytes32 => mapping(address => bool)) internal _roleChangeApprovals;
    mapping(bytes32 => uint256) internal _roleChangeApprovalCounts;
    mapping(bytes32 => uint256) internal _roleChangeInitiatedTime;
    
    /**
     * @dev Constructor initializes the DOVE token with references to managers
     * @param tokenName Name of the token
     * @param tokenSymbol Symbol of the token
     * @param adminManagerAddress Address of the admin management contract
     * @param feeManagerAddress Address of the fee management contract
     */
    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        address adminManagerAddress,
        address feeManagerAddress
    ) ERC20(tokenName, tokenSymbol) ERC20Permit(tokenName) {
        require(adminManagerAddress != address(0), "Admin manager cannot be zero address");
        require(feeManagerAddress != address(0), "Fee manager cannot be zero address");

        // Set up contract references
        adminManager = IDOVEAdmin(adminManagerAddress);
        feeManager = IDOVEFees(feeManagerAddress);
    }
}
