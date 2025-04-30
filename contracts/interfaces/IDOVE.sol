// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IDOVE
 * @dev Interface for DOVE token with charity fee and early-sell tax
 */
interface IDOVE {
    
    // ================ Events ================
    
    /**
     * @dev Emitted when token is launched
     * @param timestamp Timestamp of launch
     */
    event TokenLaunched(uint256 timestamp);
    
    /**
     * @dev Emitted when charity fee is collected
     * @param amount Amount of tokens collected as fee
     */
    event CharityFeeCollected(uint256 amount);
    
    /**
     * @dev Emitted when early sell tax is collected
     * @param seller Address selling tokens
     * @param taxAmount Amount of tokens collected as tax
     */
    event EarlySellTaxCollected(address indexed seller, uint256 taxAmount);
    
    // ================ External Functions ================
    
    /**
     * @dev Returns the maximum transaction amount allowed
     * This changes over time: lower at launch, higher after 24 hours
     * @return Maximum transaction amount in token units
     */
    function getMaxTransactionAmount() external view returns (uint256);
    
    /**
     * @dev Returns the current charity fee percentage (in basis points)
     * @return The charity fee percentage
     */
    function getCharityFee() external view returns (uint16);
    
    /**
     * @dev Returns the current charity wallet address
     * @return The charity wallet address
     */
    function getCharityWallet() external view returns (address);
    
    /**
     * @dev Returns the timestamp when the token was launched
     * @return Timestamp when the token was launched
     */
    function getLaunchTimestamp() external view returns (uint256);
    
    /**
     * @dev Returns the total amount of tokens donated to charity
     * @return Total amount of tokens donated to charity
     */
    function getTotalCharityDonations() external view returns (uint256);
    
    /**
     * @dev Returns whether the token has been officially launched
     * @return True if launched, false otherwise
     */
    function isLaunched() external view returns (bool);
    
    /**
     * @dev Returns whether the early sell tax is currently enabled
     * @return True if enabled, false otherwise
     */
    function isEarlySellTaxEnabled() external view returns (bool);
    
    /**
     * @dev Returns whether an address is excluded from fees
     * @param account Address to check
     * @return True if excluded, false otherwise
     */
    function isExcludedFromFee(address account) external view returns (bool);
    
    /**
     * @dev Returns whether an address is marked as a known DEX
     * @param dexAddress Address to check
     * @return True if it's a known DEX, false otherwise
     */
    function isKnownDex(address dexAddress) external view returns (bool);
    
    /**
     * @dev Returns the early sell tax percentage for a specific address (in basis points)
     * @param seller Address to get tax rate for
     * @return Tax percentage in basis points
     */
    function getEarlySellTaxFor(address seller) external view returns (uint16);
    
    /**
     * @dev Returns whether token transfers are paused
     * @return True if paused, false otherwise
     */
    function isPaused() external view returns (bool);
    
    /**
     * @dev Returns whether max transaction limit is enabled
     * @return True if enabled, false otherwise
     */
    function isMaxTxLimitEnabled() external view returns (bool);
}
