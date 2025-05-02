// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./DOVERoleManager.sol";
import "../interfaces/IDOVE.sol";

/**
 * @title DOVE Transfer Handler
 * @dev Handles token transfers with fee calculations and security checks
 */
abstract contract DOVETransferHandler is DOVERoleManager {
    // ================ Events ================
    
    event CharityFeeCollected(address indexed from, address indexed charity, uint256 amount);
    event MaxTransactionLimitUpdated(uint256 initialLimit, uint256 after24hLimit);
    
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
            uint256 maxAmount = _getMaxTransactionAmount();
            require(amount <= maxAmount, "DOVE: Transfer amount exceeds the maximum allowed");
        }
        
        // ===== FEES CALCULATION - Load all state variables first =====
        
        // Calculate fees using the fee manager
        (uint256 charityFeeAmount, uint256 earlySellTaxAmount) = feeManager.calculateFees(sender, recipient, amount);
        
        // Calculate final transfer amount after all fees
        uint256 transferAmount = amount - charityFeeAmount - earlySellTaxAmount;
        
        // ===== EFFECTS - Update all balances using the internal _update function =====
        
        // First transfer the main amount to recipient
        super._transfer(sender, recipient, transferAmount);
        
        // Then handle fees by transferring to respective wallets if applicable
        address charityWallet = feeManager.getCharityWallet();
        
        if (charityFeeAmount > 0) {
            super._transfer(sender, charityWallet, charityFeeAmount);
            emit CharityFeeCollected(sender, charityWallet, charityFeeAmount);
        }
        
        if (earlySellTaxAmount > 0) {
            // Burn the early sell tax by transferring to address(0)
            super._transfer(sender, address(0), earlySellTaxAmount);
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
     * @dev Get the maximum transaction amount based on current state
     * @return Max transaction amount
     */
    function _getMaxTransactionAmount() internal view returns (uint256) {
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
