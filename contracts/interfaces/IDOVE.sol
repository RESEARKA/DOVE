// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IDOVE Interface
 * @dev Interface for the DOVE token with action methods only
 * View functions are now in IDOVEInfo interface
 */
interface IDOVE {
    // ================ Events ================
    
    event Launch(uint256 timestamp);
    event CharityWalletUpdated(address indexed oldWallet, address indexed newWallet);
    event ExcludedFromFeeUpdated(address indexed account, bool excluded);
    event DexStatusUpdated(address indexed dexAddress, bool dexStatus);
    event EarlySellTaxDisabled();
    event MaxTxLimitDisabled();
    
    // ================ State-Changing Functions ================
    
    /**
     * @dev Launch the token, enabling transfers
     */
    function launch() external;
    
    /**
     * @dev Pause all token transfers
     */
    function pause() external;
    
    /**
     * @dev Unpause all token transfers
     */
    function unpause() external;
    
    /**
     * @dev Set charity wallet address
     * @param newCharityWallet New charity wallet address
     */
    function setCharityWallet(address newCharityWallet) external;
    
    /**
     * @dev Set an address as excluded or included from fees
     * @param account Address to update
     * @param excluded Whether to exclude from fees
     */
    function setExcludedFromFee(address account, bool excluded) external;
    
    /**
     * @dev Set a DEX address status
     * @param dexAddress Address to set status for
     * @param dexStatus Whether the address is a DEX
     */
    function setDexStatus(address dexAddress, bool dexStatus) external;
    
    /**
     * @dev Disable early sell tax permanently
     */
    function disableEarlySellTax() external;
    
    /**
     * @dev Disable max transaction limit permanently
     */
    function disableMaxTxLimit() external;

    /**
     * @dev Transfer fee from contract to recipient
     * @param from Address to deduct from
     * @param to Recipient address
     * @param amount Amount to transfer
     * @return Whether the transfer was successful
     */
    function transferFeeFromContract(address from, address to, uint256 amount) external returns (bool);
    
    /**
     * @dev Burn fee amount
     * @param from Address to deduct from
     * @param amount Amount to burn
     * @return Whether the burn was successful
     */
    function burnFeeFromContract(address from, uint256 amount) external returns (bool);
    
    /**
     * @dev Emit charity wallet updated event
     * @param oldWallet Old charity wallet address
     * @param newWallet New charity wallet address
     */
    function emitCharityWalletUpdated(address oldWallet, address newWallet) external;
    
    /**
     * @dev Emit excluded from fee updated event
     * @param account Address that was updated
     * @param excluded Whether the address is excluded
     */
    function emitExcludedFromFeeUpdated(address account, bool excluded) external;
    
    /**
     * @dev Emit DEX status updated event
     * @param dexAddress Address that was updated
     * @param dexStatus Whether the address is a DEX
     */
    function emitDexStatusUpdated(address dexAddress, bool dexStatus) external;
    
    /**
     * @dev Emit early sell tax disabled event
     */
    function emitEarlySellTaxDisabled() external;
}
