// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IDOVEInfo Interface
 * @dev Interface for the view functions of the DOVE token ecosystem
 * This interface contains all read-only query methods
 */
interface IDOVEInfo {
    // ================ External Functions ================
    
    /**
     * @dev Update max transaction limit status
     * @param isEnabled Whether the limit is enabled
     */
    function setMaxTxLimitEnabled(bool isEnabled) external;
    
    // ================ View Functions ================
    
    /**
     * @dev Get the charity wallet address
     * @return Address of the charity wallet
     */
    function getCharityWallet() external view returns (address);
    
    /**
     * @dev Get the charity fee percentage in basis points
     * @return Charity fee in basis points
     */
    function getCharityFee() external pure returns (uint16);
    
    /**
     * @dev Get whether an address is excluded from fees
     * @param account Address to check
     * @return Whether the address is excluded from fees
     */
    function isExcludedFromFee(address account) external view returns (bool);
    
    /**
     * @dev Get whether an address is marked as a DEX
     * @param account Address to check
     * @return Whether the address is a DEX
     */
    function getDexStatus(address account) external view returns (bool);
    
    /**
     * @dev Get the maximum transaction amount
     * @return Maximum transaction amount
     */
    function getMaxTransactionAmount() external view returns (uint256);
    
    /**
     * @dev Get the admin contract address
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
}
