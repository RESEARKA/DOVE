// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IDOVEInfo Interface
 * @dev Interface for the view functions of the DOVEv3 token ecosystem
 * This interface contains all read-only query methods
 */
interface IDOVEInfo {
    /**
     * @dev Get the charity wallet address
     * @return Address of the charity wallet
     */
    function charityWallet() external view returns (address);
    
    /**
     * @dev Get the liquidity manager contract address
     * @return Address of the liquidity manager
     */
    function liquidityManager() external view returns (address);
    
    /**
     * @dev Get the launch timestamp of the token
     * @return Timestamp when the token was launched
     */
    function launchTimestamp() external view returns (uint256);
    
    /**
     * @dev Calculate the current sell tax based on time since launch
     * @return Current sell tax in basis points
     */
    function getCurrentSellTax() external view returns (uint256);
    
    /**
     * @dev Check if an address is exempt from fees
     * @param account Address to check
     * @return Whether the address is exempt from fees
     */
    function isExemptFromFees(address account) external view returns (bool);
}
