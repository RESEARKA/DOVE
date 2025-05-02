// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./DOVERoleManager.sol";

/**
 * @title DOVE Transfer Handler
 * @dev Handles token transfers with fee calculations and security checks
 */
abstract contract DOVETransferHandler is DOVERoleManager {
    // ================ Events ================
    
    event CharityFeeCollected(address indexed from, address indexed charity, uint256 amount);
    event EarlySellTaxCollected(address indexed from, uint256 amount);
    event MaxTransactionLimitUpdated(uint256 initialLimit, uint256 after24hLimit);
    
    /**
     * @dev Override of the OpenZeppelin ERC20 _update function
     * This function safely updates token balances and emits events
     */
    function _update(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        // Skip pointless zero transfers to save gas
        if (amount == 0) {
            return;
        }
        
        // SECURITY: Explicit balance check for underflow protection
        // Even though Solidity 0.8+ has built-in overflow checking, this makes the check explicit
        // and provides a more descriptive error message
        if (sender != address(0)) {
            require(balanceOf(sender) >= amount, "ERC20: transfer amount exceeds balance");
        }
        
        // Use the parent implementation to handle the balance updates
        super._update(sender, recipient, amount);
    }
    
    /**
     * @dev Override of the OpenZeppelin ERC20 _transfer function to include:
     * - Reentrancy protection with nonReentrant modifier
     * - Thorough application of checks-effects-interactions pattern
     * - Fee calculations and distribution
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override nonReentrant {
        // CHECKS - Guard clauses and state validation
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "ERC20: transfer amount must be greater than zero");
        
        // Reject transfers when paused, unless the sender has the OPERATOR_ROLE
        if (adminManager.isPaused()) {
            require(hasRole(OPERATOR_ROLE, msg.sender), "ERC20Pausable: transfers paused and caller is not an operator");
        }
        
        // Check for max transaction limit if enabled
        if (adminManager.isMaxTxLimitEnabled() && 
            !feeManager.isExcludedFromFee(sender) && 
            !feeManager.isExcludedFromFee(recipient)) {
            // Get the current max transaction amount
            uint256 maxAmount = getMaxTransactionAmount();
            require(amount <= maxAmount, "DOVE: Transfer amount exceeds the maximum allowed");
        }
        
        // ===== FEES CALCULATION - Load all state variables first =====
        
        // Calculate fees using the fee manager
        (uint256 charityFeeAmount, uint256 earlySellTaxAmount) = calculateFees(sender, recipient, amount);
        
        // Calculate final transfer amount after all fees
        uint256 transferAmount = amount - charityFeeAmount - earlySellTaxAmount;
        
        // ===== EFFECTS - Update all balances using the internal _update function =====
        
        // First transfer the main amount to recipient
        super._update(sender, recipient, transferAmount);
        
        // Then handle fees by transferring to respective wallets if applicable
        address charityWallet = feeManager.getCharityWallet();
        
        if (charityFeeAmount > 0) {
            super._update(sender, charityWallet, charityFeeAmount);
            emit CharityFeeCollected(sender, charityWallet, charityFeeAmount);
        }
        
        if (earlySellTaxAmount > 0) {
            // Burn the early sell tax by transferring to address(0)
            super._update(sender, address(0), earlySellTaxAmount);
            emit EarlySellTaxCollected(sender, earlySellTaxAmount);
        }
        
        // ===== INTERACTIONS - Only after all state changes are complete =====
        
        // If this is the first transfer, mark token as launched
        if (!feeManager.isLaunched()) {
            // Set launch timestamp through fee manager
            feeManager._setLaunched(block.timestamp);
        }
        
        // Update charity donation tracking
        if (charityFeeAmount > 0) {
            feeManager._addCharityDonation(charityFeeAmount);
        }
    }
    
    /**
     * @dev Calculate fees for a transfer
     * @param sender Address sending tokens
     * @param recipient Address receiving tokens
     * @param amount Amount being transferred
     * @return charityFeeAmount Amount to be taken as charity fee
     * @return earlySellTaxAmount Amount to be taken as early sell tax
     */
    function calculateFees(
        address sender,
        address recipient,
        uint256 amount
    ) internal view returns (uint256 charityFeeAmount, uint256 earlySellTaxAmount) {
        // Skip fee calculation if excluded addresses
        if (feeManager.isExcludedFromFee(sender) || feeManager.isExcludedFromFee(recipient)) {
            return (0, 0);
        }
        
        // Calculate charity fee
        charityFeeAmount = feeManager.calculateCharityFee(amount);
        
        // Calculate early sell tax (only on sells to DEX)
        if (feeManager.isEarlySellTaxEnabled() && feeManager.isKnownDex(recipient)) {
            earlySellTaxAmount = feeManager.calculateEarlySellTax(amount, sender, true);
        }
        
        return (charityFeeAmount, earlySellTaxAmount);
    }
    
    /**
     * @dev Get the maximum transaction amount based on current state
     * @return Max transaction amount
     */
    function getMaxTransactionAmount() public view returns (uint256) {
        // Early check - if max tx limit is disabled, return max uint256
        if (!adminManager.isMaxTxLimitEnabled()) {
            return type(uint256).max;
        }
        
        // If token is not launched yet, use initial limit
        if (!feeManager.isLaunched()) {
            return MAX_TX_INITIAL;
        }
        
        // Calculate time elapsed since launch
        uint256 timeElapsed = block.timestamp - feeManager.getLaunchTimestamp();
        
        // After 24 hours, use higher limit
        if (timeElapsed >= 1 days) {
            return MAX_TX_AFTER_24H;
        }
        
        // Default to initial limit
        return MAX_TX_INITIAL;
    }
}
