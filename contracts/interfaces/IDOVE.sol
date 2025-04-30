// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IDOVE
 * @dev Interface for the DOVE token with reflection and early-sell tax functionality
 */
interface IDOVE {
    /**
     * @dev Returns the current reflection fee percentage (in basis points)
     * @return Fee percentage where 100 = 1%
     */
    function getReflectionFee() external view returns (uint16);

    /**
     * @dev Returns the current early-sell tax percentage for a specific account
     * @param account Address to check early-sell tax for
     * @return Early sell tax percentage where 100 = 1%
     */
    function getEarlySellTaxFor(address account) external view returns (uint16);
    
    /**
     * @dev Excludes an account from paying fees
     * @param account Address to exclude
     */
    function excludeFromFee(address account) external;
    
    /**
     * @dev Includes an account in fee payment
     * @param account Address to include
     */
    function includeInFee(address account) external;
    
    /**
     * @dev Checks if an account is excluded from paying fees
     * @param account Address to check
     * @return True if account is excluded from fees
     */
    function isExcludedFromFee(address account) external view returns (bool);
    
    /**
     * @dev Returns the maximum transaction amount
     * @return Maximum amount that can be transferred in a single transaction
     */
    function getMaxTransactionAmount() external view returns (uint256);
    
    /**
     * @dev Permanently disables the early-sell tax mechanism
     * Can only be called by owner
     */
    function disableEarlySellTax() external;
    
    /**
     * @dev Permanently disables the max transaction limit
     * Can only be called by owner
     */
    function disableMaxTxLimit() external;
    
    /**
     * @dev Returns the timestamp when the token was first transferred/traded
     * @return Timestamp in seconds
     */
    function getLaunchTimestamp() external view returns (uint256);

    // Events
    event ReflectionFeeCollected(uint256 tFee);
    event EarlySellTaxCollected(address indexed seller, uint256 taxAmount);
    event ExcludeFromFee(address indexed account, bool excluded);
    event MaxTxLimitDisabled();
    event EarlySellTaxDisabled();
}
