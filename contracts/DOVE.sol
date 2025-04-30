// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IDOVE.sol";
import "./DOVEFees.sol";
import "./DOVEAdmin.sol";

/**
 * @title DOVE Token
 * @dev Implementation of the DOVE token with charity fee and early-sell tax mechanisms
 */
contract DOVE is ERC20Permit, ReentrancyGuard, IDOVE {
    
    // ================ Constants ================
    
    // Base supply: 100 billion tokens with 18 decimals
    uint256 private constant TOTAL_SUPPLY = 100_000_000_000 * 1e18;
    
    // Transaction limits
    uint256 private constant MAX_TX_INITIAL = TOTAL_SUPPLY * 2 / 1000; // 0.2%
    uint256 private constant MAX_TX_AFTER_24H = TOTAL_SUPPLY * 5 / 1000; // 0.5%
    
    // ================ State Variables ================
    
    // Fee management module - handles charity fee and early sell tax
    DOVEFees public immutable feeManager;
    
    // Admin functionality module - handles owner controls
    DOVEAdmin public immutable adminManager;
    
    // ================ Constructor ================
    
    /**
     * @dev Constructor initializes the DOVE token with charity wallet
     * @param initialCharityWallet Address to receive charity fees
     */
    constructor(address initialCharityWallet) ERC20("DOVE", "DOVE") ERC20Permit("DOVE") {
        require(initialCharityWallet != address(0), "Charity wallet cannot be zero address");
        
        // Set up fee management module
        feeManager = new DOVEFees(initialCharityWallet);
        
        // Set up admin module
        adminManager = new DOVEAdmin(feeManager);
        
        // Transfer ownership of modules to token deployer
        feeManager.transferOwnership(msg.sender);
        adminManager.transferOwnership(msg.sender);
        
        // Mint total supply to deployer
        _mint(msg.sender, TOTAL_SUPPLY);
        
        // Exclude owner, token contract, and charity wallet from fees
        feeManager._setExcludedFromFee(msg.sender, true);
        feeManager._setExcludedFromFee(address(this), true);
        feeManager._setExcludedFromFee(initialCharityWallet, true);
    }
    
    // ================ External View Functions ================
    
    /**
     * @dev See {IDOVE-getMaxTransactionAmount}
     */
    function getMaxTransactionAmount() external view returns (uint256) {
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
    
    /**
     * @dev See {IDOVE-getCharityFee} - delegated to fee manager
     */
    function getCharityFee() external view returns (uint16) {
        return feeManager.getCharityFee();
    }
    
    /**
     * @dev See {IDOVE-getCharityWallet} - delegated to fee manager
     */
    function getCharityWallet() external view returns (address) {
        return feeManager.getCharityWallet();
    }
    
    /**
     * @dev See {IDOVE-getLaunchTimestamp} - delegated to fee manager
     */
    function getLaunchTimestamp() external view returns (uint256) {
        return feeManager.getLaunchTimestamp();
    }
    
    /**
     * @dev See {IDOVE-getTotalCharityDonations} - delegated to fee manager
     */
    function getTotalCharityDonations() external view returns (uint256) {
        return feeManager.getTotalCharityDonations();
    }
    
    /**
     * @dev See {IDOVE-isLaunched} - delegated to fee manager
     */
    function isLaunched() external view returns (bool) {
        return feeManager.isLaunched();
    }
    
    /**
     * @dev See {IDOVE-isEarlySellTaxEnabled} - delegated to fee manager
     */
    function isEarlySellTaxEnabled() external view returns (bool) {
        return feeManager.isEarlySellTaxEnabled();
    }
    
    /**
     * @dev See {IDOVE-isExcludedFromFee} - delegated to fee manager
     */
    function isExcludedFromFee(address account) external view returns (bool) {
        return feeManager.isExcludedFromFee(account);
    }
    
    /**
     * @dev See {IDOVE-isKnownDex} - delegated to fee manager
     */
    function isKnownDex(address dexAddress) external view returns (bool) {
        return feeManager.isKnownDex(dexAddress);
    }
    
    /**
     * @dev See {IDOVE-getEarlySellTaxFor} - delegated to fee manager
     */
    function getEarlySellTaxFor(address seller) external view returns (uint16) {
        return feeManager.getEarlySellTaxFor(seller);
    }
    
    /**
     * @dev See {IDOVE-isPaused} - delegated to admin manager
     */
    function isPaused() external view returns (bool) {
        return adminManager.isPaused();
    }
    
    /**
     * @dev See {IDOVE-isMaxTxLimitEnabled} - delegated to admin manager
     */
    function isMaxTxLimitEnabled() external view returns (bool) {
        return adminManager.isMaxTxLimitEnabled();
    }
    
    // ================ Internal Functions ================
    
    /**
     * @dev Override _transfer function to apply charity fee and transaction limits
     * @param from Sender address
     * @param to Recipient address
     * @param amount Amount of tokens to transfer
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override nonReentrant {
        // Check if paused
        require(!adminManager.isPaused(), "Token transfers are paused");
        
        // Skip all checks for zero transfers
        if (amount == 0) {
            super._transfer(from, to, amount);
            return;
        }
        
        // Cache address checks to avoid redundant operations
        bool isMint = from == address(0);
        bool isBurn = to == address(0);
        bool isRealTransfer = !isMint && !isBurn;
        bool isSenderExcluded = feeManager.isExcludedFromFee(from);
        bool isReceiverExcluded = feeManager.isExcludedFromFee(to);
        bool isSellToKnownDex = feeManager.isKnownDex(to);
        
        // Set launch timestamp on first real transfer only if not explicitly launched
        // This is a fallback mechanism in case launch() wasn't called
        if (!feeManager.isLaunched() && isRealTransfer) {
            feeManager._setLaunched(block.timestamp);
            emit TokenLaunched(block.timestamp);
        }
        
        // Check max transaction limit
        if (adminManager.isMaxTxLimitEnabled() && 
            isRealTransfer && 
            !isSenderExcluded && 
            !isReceiverExcluded) {
            require(amount <= this.getMaxTransactionAmount(), "Transfer amount exceeds max transaction limit");
        }
        
        // Calculate fees - clearly separate different fee types for better tracking
        uint16 charityFeePercent = 0;
        uint16 earlySellTaxPercent = 0;
        
        // Apply charity fee if applicable (excludes mint, burn, and excluded addresses)
        if (isRealTransfer && !isSenderExcluded && !isReceiverExcluded) {
            charityFeePercent = feeManager.getCharityFee();
        }
        
        // Add early sell tax if applicable (only applies to sells to DEX addresses)
        if (feeManager.isEarlySellTaxEnabled() && !isMint && !isSenderExcluded && isSellToKnownDex) {
            earlySellTaxPercent = feeManager.getEarlySellTaxFor(from);
        }
        
        // Total fee percentage is the sum of both fee types
        uint16 totalFeePercent = charityFeePercent + earlySellTaxPercent;
        
        // Process the transfer with fees if applicable
        if (totalFeePercent > 0) {
            // Calculate fee amount with improved precision to avoid rounding errors
            // Always multiply first, then divide to maintain proper precision
            uint256 feeAmount = amount * totalFeePercent / 10000;
            
            // Transfer amount after deducting fees
            uint256 transferAmount = amount - feeAmount;
            
            // Calculate exact amount for each fee type based on percentages
            uint256 charityFee = 0;
            uint256 earlySellTax = 0;
            
            if (totalFeePercent > 0) {
                // Calculate each fee proportionally to avoid rounding errors
                charityFee = feeAmount * charityFeePercent / totalFeePercent;
                earlySellTax = feeAmount - charityFee;
            }
            
            // Apply checks-effects-interactions pattern to prevent reentrancy
            // First update the direct transfer (main transfer with reduced amount)
            super._transfer(from, to, transferAmount);
            
            // Then process fees after primary transfer is complete
            if (charityFee > 0) {
                feeManager._addCharityDonation(charityFee);
                super._transfer(from, feeManager.getCharityWallet(), charityFee);
                emit CharityFeeCollected(charityFee);
            }
            
            // Early sell tax is automatically burned
            if (earlySellTax > 0) {
                super._burn(from, earlySellTax); // Burn early sell tax
                emit EarlySellTaxCollected(from, earlySellTax);
            }
        } else {
            // No fees, do regular transfer
            super._transfer(from, to, amount);
        }
    }
}
