// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IDOVEAdmin.sol";
import "../interfaces/IDOVEGovernance.sol";

/**
 * @title DOVEGovernance
 * @dev Handles admin contract update proposals and approvals
 * Implements multi-signature governance for the DOVE token ecosystem
 */
contract DOVEGovernance is IDOVEGovernance, ReentrancyGuard {
    // ================ Constants ================
    
    // 7 day expiration for proposals (in seconds)
    uint256 public constant PROPOSAL_EXPIRY = 7 days;
    
    // Number of required approvals for admin update
    uint8 public constant REQUIRED_APPROVALS = 2;
    
    // ================ State Variables ================
    
    // Admin contract reference
    IDOVEAdmin private _adminContract;
    
    // Admin update proposal tracking
    struct AdminUpdateProposal {
        address newAdmin;
        uint256 timestamp;
        uint256 approvalCount;
        bool executed;
        mapping(address => bool) hasApproved;
    }
    
    // Admin update proposals
    uint256 private _currentProposalId;
    mapping(uint256 => AdminUpdateProposal) private _adminUpdateProposals;
    
    // Initialization flag
    bool private _initialized;
    
    // ================ Constructor ================
    
    /**
     * @dev Constructor
     * Empty constructor - initialization happens in initialize function
     */
    constructor() {}
    
    /**
     * @dev Initialize contract with required dependencies
     * @param adminContract Initial admin contract
     * @return True if initialization was successful
     */
    function initialize(address adminContract) external returns (bool) {
        require(!_initialized, "Already initialized");
        require(adminContract != address(0), "Admin cannot be zero address");
        
        _adminContract = IDOVEAdmin(adminContract);
        _initialized = true;
        
        return true;
    }
    
    // ================ Modifiers ================
    
    /**
     * @dev Restricts function to admin contract
     */
    modifier onlyAdmin() {
        require(msg.sender == address(_adminContract), "Caller is not the admin contract");
        _;
    }
    
    // ================ External Functions ================
    
    /**
     * @dev Propose new admin contract address (multisig operation)
     * @param newAdminContract Address of the new admin contract
     * @return proposalId ID of the created proposal
     */
    function proposeAdminUpdate(address newAdminContract) external onlyAdmin returns (uint256 proposalId) {
        require(newAdminContract != address(0), "New admin cannot be zero address");
        require(newAdminContract != address(_adminContract), "New admin same as current");
        
        // Create new proposal ID
        proposalId = _currentProposalId++;
        
        // Initialize proposal
        AdminUpdateProposal storage proposal = _adminUpdateProposals[proposalId];
        proposal.newAdmin = newAdminContract;
        proposal.timestamp = block.timestamp;
        proposal.approvalCount = 1; // Proposer automatically approves
        proposal.hasApproved[msg.sender] = true;
        proposal.executed = false;
        
        emit AdminUpdateProposed(proposalId, msg.sender, newAdminContract);
        emit AdminUpdateApproved(proposalId, msg.sender);
        
        return proposalId;
    }
    
    /**
     * @dev Approve admin update proposal
     * @param proposalId ID of the proposal to approve
     */
    function approveAdminUpdate(uint256 proposalId) external onlyAdmin {
        AdminUpdateProposal storage proposal = _adminUpdateProposals[proposalId];
        
        require(proposal.newAdmin != address(0), "Proposal does not exist");
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.hasApproved[msg.sender], "Already approved");
        require(
            block.timestamp <= proposal.timestamp + PROPOSAL_EXPIRY,
            "Proposal expired"
        );
        
        // Mark as approved
        proposal.hasApproved[msg.sender] = true;
        proposal.approvalCount += 1;
        
        emit AdminUpdateApproved(proposalId, msg.sender);
        
        // Execute if enough approvals
        if (proposal.approvalCount >= REQUIRED_APPROVALS) {
            proposal.executed = true;
            address oldAdmin = address(_adminContract);
            _adminContract = IDOVEAdmin(proposal.newAdmin);
            
            emit AdminUpdateExecuted(proposalId, oldAdmin, proposal.newAdmin);
        }
    }
    
    // ================ View Functions ================
    
    /**
     * @dev Get admin contract address
     * @return Address of the admin contract
     */
    function getAdminContract() external view override returns (address) {
        return address(_adminContract);
    }
    
    /**
     * @dev Get admin update proposal details
     * @param proposalId ID of the proposal
     * @return newAdmin Proposed admin contract address
     * @return timestamp Time when proposal was created
     * @return approvalCount Number of approvals
     * @return executed Whether proposal has been executed
     */
    function getAdminUpdateProposal(uint256 proposalId) external view override returns (
        address newAdmin,
        uint256 timestamp,
        uint256 approvalCount,
        bool executed
    ) {
        AdminUpdateProposal storage proposal = _adminUpdateProposals[proposalId];
        
        return (
            proposal.newAdmin,
            proposal.timestamp,
            proposal.approvalCount,
            proposal.executed
        );
    }
    
    /**
     * @dev Check if an address has approved a proposal
     * @param proposalId ID of the proposal
     * @param approver Address to check
     * @return Whether the address has approved the proposal
     */
    function hasApproved(uint256 proposalId, address approver) external view override returns (bool) {
        return _adminUpdateProposals[proposalId].hasApproved[approver];
    }
}
