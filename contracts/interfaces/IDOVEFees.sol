// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IDOVEFees
 * @dev Interface for DOVE token fee management
 */
interface IDOVEFees {
    
    // ================ Events ================
    
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
    
    /**
     * @dev Emitted when charity wallet is updated
     * @param newCharityWallet New charity wallet address
     */
    event CharityWalletUpdated(address indexed newCharityWallet);
    
    /**
     * @dev Emitted when early sell tax is disabled
     */
    event EarlySellTaxDisabled();
    
    /**
     * @dev Emitted when an address's excluded status is updated
     * @param account Address being updated
     * @param excluded Whether address is excluded or not
     */
    event ExcludedFromFeeUpdated(address indexed account, bool excluded);
    
    /**
     * @dev Emitted when a DEX status is updated
     * @param dexAddress Address being updated
     * @param isDex Whether address is a DEX or not
     */
    event KnownDexUpdated(address indexed dexAddress, bool isDex);
    
    /**
     * @dev Emitted when the token is launched
     * @param launchTimestamp Timestamp of launch
     */
    event Launched(uint256 launchTimestamp);
    
    /**
     * @dev Emitted when tax rate durations are updated
     * @param day1 Duration for first tax rate
     * @param day2 Duration for second tax rate
     * @param day3 Duration for third tax rate
     */
    event TaxRateDurationsUpdated(uint256 day1, uint256 day2, uint256 day3);
    
    // ================ External Functions ================
    
    /**
     * @dev Returns the current charity fee percentage (in basis points)
     * @return The charity fee percentage
     */
    function getCharityFee() external pure returns (uint16);
    
    /**
     * @dev Returns the current charity wallet address
     * @return The charity wallet address
     */
    function getCharityWallet() external view returns (address);
    
    /**
     * @dev Returns the total amount of tokens donated to charity
     * @return Total amount of tokens donated to charity
     */
    function getTotalCharityDonations() external view returns (uint256);
    
    /**
     * @dev Returns the timestamp when the token was launched
     * @return Timestamp when the token was launched
     */
    function getLaunchTimestamp() external view returns (uint256);
    
    /**
     * @dev Returns whether the early sell tax is currently enabled
     * @return True if enabled, false otherwise
     */
    function isEarlySellTaxEnabled() external view returns (bool);
    
    /**
     * @dev Returns whether the token has been officially launched
     * @return True if launched, false otherwise
     */
    function isLaunched() external view returns (bool);
    
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
     * @dev Returns the durations for each tax rate period
     * @return day1 Duration for first tax rate (in seconds)
     * @return day2 Duration for second tax rate (in seconds)
     * @return day3 Duration for third tax rate (in seconds)
     */
    function getTaxRateDurations() external view returns (uint256, uint256, uint256);
    
    // ================ Internal Functions ================
    
    /**
     * @dev Set launched status - only callable by the token contract
     * @param launchTimestamp The timestamp to set as launch time
     */
    function _setLaunched(uint256 launchTimestamp) external;
    
    /**
     * @dev Track charity donations - only callable by the token contract
     * @param amount Amount being donated
     */
    function _addCharityDonation(uint256 amount) external;
    
    /**
     * @dev Set an address to be excluded from fee - only callable by admin
     * @param account Address to exclude
     * @param excluded Whether to exclude or include
     */
    function _setExcludedFromFee(address account, bool excluded) external;
    
    /**
     * @dev Set an address as known DEX - only callable by admin
     * @param dexAddress Address to mark as DEX
     * @param isDex Whether this address is a DEX or not
     */
    function _setKnownDex(address dexAddress, bool isDex) external;
    
    /**
     * @dev Update charity wallet - only callable by admin
     * @param newCharityWallet New charity wallet address
     */
    function _updateCharityWallet(address newCharityWallet) external;
    
    /**
     * @dev Update tax rate durations - only callable by admin
     * @param day1 Duration for first tax rate (in seconds)
     * @param day2 Duration for second tax rate (in seconds)
     * @param day3 Duration for third tax rate (in seconds)
     */
    function _updateTaxRateDurations(
        uint256 day1,
        uint256 day2,
        uint256 day3
    ) external;
    
    /**
     * @dev Disable early sell tax - only callable by admin
     */
    function _disableEarlySellTax() external;
}
