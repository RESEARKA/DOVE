// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IDOVEAdmin
 * @dev Interface for DOVE token admin functions
 */
interface IDOVEAdmin {
    
    // ================ Events ================
    
    /**
     * @dev Emitted when token is launched
     * @param timestamp Timestamp of launch
     */
    event TokenLaunched(uint256 timestamp);
    
    /**
     * @dev Emitted when DEX status is updated
     * @param dexAddress Address being updated
     * @param isDex Whether address is a DEX or not
     */
    event DexStatusUpdated(address indexed dexAddress, bool isDex);
    
    /**
     * @dev Emitted when tax durations are updated
     * @param day1 Duration for first tax rate
     * @param day2 Duration for second tax rate
     * @param day3 Duration for third tax rate
     */
    event TaxDurationsUpdated(uint256 day1, uint256 day2, uint256 day3);
    
    /**
     * @dev Emitted when max transaction limit is disabled
     */
    event MaxTxLimitDisabled();
    
    /**
     * @dev Emitted when early sell tax is disabled
     */
    event EarlySellTaxDisabled();
    
    /**
     * @dev Emitted when an address is excluded from fee
     * @param account Address being excluded
     * @param excluded Whether address is excluded or not
     */
    event ExcludeFromFee(address indexed account, bool excluded);
    
    /**
     * @dev Emitted when charity wallet is updated
     * @param oldWallet Previous charity wallet
     * @param newWallet New charity wallet
     */
    event CharityWalletUpdated(address indexed oldWallet, address indexed newWallet);
    
    // ================ External Functions ================
    
    /**
     * @dev Officially launches the token and starts tax period counting
     * Can only be called by owner and only once
     */
    function launch() external;
    
    /**
     * @dev Pauses all token transfers
     * Can only be called by owner
     */
    function pause() external;
    
    /**
     * @dev Unpauses all token transfers
     * Can only be called by owner
     */
    function unpause() external;
    
    /**
     * @dev Sets whether an address is a known DEX or not
     * @param dexAddress Address to set status for
     * @param isDex Whether the address is a DEX
     * Can only be called by owner
     */
    function setDexStatus(address dexAddress, bool isDex) external;
    
    /**
     * @dev Sets whether an address is excluded from paying fees
     * @param account Address to exclude/include
     * @param excluded Whether to exclude or include
     * Can only be called by owner
     */
    function excludeFromFee(address account, bool excluded) external;
    
    /**
     * @dev Updates the charity wallet address
     * @param newCharityWallet New charity wallet address
     * Can only be called by owner
     */
    function updateCharityWallet(address newCharityWallet) external;
    
    /**
     * @dev Updates the durations for each tax rate period
     * @param day1 Duration for first tax rate (in seconds)
     * @param day2 Duration for second tax rate (in seconds)
     * @param day3 Duration for third tax rate (in seconds)
     * Can only be called by owner
     */
    function updateTaxRateDurations(
        uint256 day1,
        uint256 day2,
        uint256 day3
    ) external;
    
    /**
     * @dev Permanently disables the early sell tax
     * Can only be called by owner and is irreversible
     */
    function disableEarlySellTax() external;
    
    /**
     * @dev Permanently disables the max transaction limit
     * Can only be called by owner and is irreversible
     */
    function disableMaxTxLimit() external;
    
    /**
     * @dev Checks if max transaction limit is enabled
     * @return Whether max transaction limit is enabled
     */
    function isMaxTxLimitEnabled() external view returns (bool);
    
    /**
     * @dev Checks if token transfers are paused
     * @return Whether token transfers are paused
     */
    function isPaused() external view returns (bool);
}
