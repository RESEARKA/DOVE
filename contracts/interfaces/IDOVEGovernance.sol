// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IDOVEGovernance
 * @dev Interface for DOVE governance functionality
 */
interface IDOVEGovernance {
    // ================ Function Declarations ================
    
    /**
     * @dev Propose new admin contract address
     * @param newAdminContract Address of the new admin contract
     * @return proposalId ID of the created proposal
     */
    function proposeAdminUpdate(address newAdminContract) external returns (uint256 proposalId);
    
    /**
     * @dev Approve admin update proposal
     * @param proposalId ID of the proposal to approve
     */
    function approveAdminUpdate(uint256 proposalId) external;
    
    /**
     * @dev Get admin contract address
     * @return Address of the admin contract
     */
    function getAdminContract() external view returns (address);
    
    /**
     * @dev Get admin update proposal details
     * @param proposalId ID of the proposal
     * @return newAdmin Proposed admin contract address
     * @return timestamp Time when proposal was created
     * @return approvalCount Number of approvals
     * @return executed Whether proposal has been executed
     */
    function getAdminUpdateProposal(uint256 proposalId) external view returns (
        address newAdmin,
        uint256 timestamp,
        uint256 approvalCount,
        bool executed
    );
    
    /**
     * @dev Check if an address has approved a proposal
     * @param proposalId ID of the proposal
     * @param approver Address to check
     * @return Whether the address has approved the proposal
     */
    function hasApproved(uint256 proposalId, address approver) external view returns (bool);
    
    // ================ Events ================
    
    /**
     * @dev Emitted when a new admin update is proposed
     * @param proposalId ID of the proposal
     * @param proposer Address that proposed the update
     * @param newAdmin Proposed admin contract address
     */
    event AdminUpdateProposed(uint256 indexed proposalId, address indexed proposer, address indexed newAdmin);
    
    /**
     * @dev Emitted when an admin update is approved
     * @param proposalId ID of the proposal
     * @param approver Address that approved the update
     */
    event AdminUpdateApproved(uint256 indexed proposalId, address indexed approver);
    
    /**
     * @dev Emitted when an admin update is executed
     * @param proposalId ID of the proposal
     * @param oldAdmin Old admin contract address
     * @param newAdmin New admin contract address
     */
    event AdminUpdateExecuted(uint256 indexed proposalId, address oldAdmin, address newAdmin);
}
