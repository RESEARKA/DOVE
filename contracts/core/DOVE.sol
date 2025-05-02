// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IDOVE.sol";
import "../interfaces/IDOVEAdmin.sol";
import "../interfaces/IDOVEFees.sol";
import "../access/RoleManager.sol";

/**
 * @title DOVE Token
 * @dev Implementation of DOVE token with charity fee and early-sell tax
 */
contract DOVE is ERC20Permit, ReentrancyGuard, RoleManager, IDOVE {
    // ================ Constants ================
    
    // Base supply: 100 billion tokens with 18 decimals
    uint256 private constant TOTAL_SUPPLY = 100_000_000_000 * 1e18;
    
    // Maximum transaction limits
    uint256 private constant MAX_TX_INITIAL = 2_000_000_000 * 1e18; // 2% of supply
    uint256 private constant MAX_TX_STANDARD = 5_000_000_000 * 1e18; // 5% of supply
    
    // ================ State Variables ================
    
    // Manager interfaces for admin and fee functionality
    IDOVEAdmin public immutable adminManager;
    IDOVEFees public immutable feeManager;
    
    // ================ Constructor ================
    
    /**
     * @dev Constructor initializes token with 100 billion supply and sets up admin contracts
     * @param adminManagerAddress Address of the admin manager contract
     * @param feeManagerAddress Address of the fee manager contract
     */
    constructor(
        address adminManagerAddress,
        address feeManagerAddress
    ) ERC20("DOVE", "DOVE") ERC20Permit("DOVE") {
        // Validate input addresses
        require(adminManagerAddress != address(0), "Admin manager cannot be zero address");
        require(feeManagerAddress != address(0), "Fee manager cannot be zero address");
        
        // Validate admin contract ownership (they should be owned by the deployer)
        address deployer = _msgSender();
        require(Ownable2Step(adminManagerAddress).owner() == deployer, "Deployer must own admin manager");
        require(Ownable2Step(feeManagerAddress).owner() == deployer, "Deployer must own fee manager");
        
        // Grant deployer the DEFAULT_ADMIN_ROLE for role management
        _grantRole(DEFAULT_ADMIN_ROLE, deployer);
        
        // Set up manager contracts
        adminManager = IDOVEAdmin(adminManagerAddress);
        feeManager = IDOVEFees(feeManagerAddress);
        
        // Mint initial supply to deployer
        _mint(deployer, TOTAL_SUPPLY);
    }
    
    // ================ Public View Functions ================
    
    /**
     * @dev Gets the charity wallet address from the fee manager
     * @return Address of the charity wallet
     */
    function getCharityWallet() external view returns (address) {
        return feeManager.getCharityWallet();
    }
    
    /**
     * @dev Gets the charity fee percentage
     * @return Charity fee as a percentage (in basis points)
     */
    function getCharityFee() external view returns (uint16) {
        return feeManager.getCharityFee();
    }
    
    /**
     * @dev Gets the effective transfer amount after deducting fees
     * @param sender Sender address
     * @param recipient Recipient address
     * @param amount Amount of tokens to transfer
     * @return Effective transfer amount after fees
     */
    function getEffectiveTransferAmount(address sender, address recipient, uint256 amount) external view returns (uint256) {
        // Skip calculations if either sender or recipient is excluded
        if (feeManager.isExcludedFromFee(sender) || feeManager.isExcludedFromFee(recipient)) {
            return amount;
        }
        
        // Get fee amounts
        (uint256 charityFeeAmount, uint256 earlySellTaxAmount) = feeManager.calculateFees(sender, recipient, amount);
        
        // Return amount minus fees
        return amount - charityFeeAmount - earlySellTaxAmount;
    }
    
    /**
     * @dev Gets the total amount of tokens collected as charity fees
     * @return Total charity fee amount
     */
    function getTotalCharityDonations() external view returns (uint256) {
        return feeManager.getTotalCharityDonations();
    }
    
    /**
     * @dev Checks if a given address is a known DEX
     * @param dexAddress Address to check
     * @return Whether the address is a known DEX
     */
    function isKnownDex(address dexAddress) external view returns (bool) {
        return feeManager.isKnownDex(dexAddress);
    }
    
    /**
     * @dev Gets the early sell tax percentage for a seller
     * @param seller Address selling tokens
     * @return Early sell tax percentage (in basis points)
     */
    function getEarlySellTaxFor(address seller) external view returns (uint16) {
        return feeManager.getEarlySellTaxFor(seller);
    }
    
    /**
     * @dev Checks if the token has been launched
     * @return Whether the token has been launched
     */
    function isLaunched() external view returns (bool) {
        return feeManager.isLaunched();
    }
    
    /**
     * @dev Checks if early sell tax is enabled
     * @return Whether early sell tax is enabled
     */
    function isEarlySellTaxEnabled() external view returns (bool) {
        return feeManager.isEarlySellTaxEnabled();
    }
    
    /**
     * @dev Gets the launch timestamp
     * @return Unix timestamp of token launch
     */
    function getLaunchTimestamp() external view returns (uint256) {
        return feeManager.getLaunchTimestamp();
    }
    
    /**
     * @dev Checks if a given address is excluded from fees
     * @param account Address to check
     * @return Whether the address is excluded from fees
     */
    function isExcludedFromFee(address account) external view returns (bool) {
        return feeManager.isExcludedFromFee(account);
    }
    
    /**
     * @dev Checks if token is paused
     * @return Whether the token is paused
     */
    function isPaused() external view returns (bool) {
        return adminManager.isPaused();
    }
    
    /**
     * @dev Checks if maximum transaction limit is enabled
     * @return Whether the max tx limit is enabled
     */
    function isMaxTxLimitEnabled() external view returns (bool) {
        return adminManager.isMaxTxLimitEnabled();
    }
    
    /**
     * @dev Gets the maximum transaction amount
     * This changes over time: lower at launch, higher after 24 hours
     * @return Maximum transaction amount in token units
     */
    function getMaxTransactionAmount() external view returns (uint256) {
        // Early check - if max tx limit is disabled, return max uint256
        bool isMaxTxLimitEnabledVar = adminManager.isMaxTxLimitEnabled();
        if (!isMaxTxLimitEnabledVar) {
            return type(uint256).max;
        }
        
        // If token is not launched yet, use initial limit
        bool isLaunchedVar = feeManager.isLaunched();
        if (!isLaunchedVar) {
            return MAX_TX_INITIAL;
        }
        
        // Calculate time elapsed since launch
        uint256 timeElapsed = block.timestamp - feeManager.getLaunchTimestamp();
        
        // After 24 hours, use higher limit
        if (timeElapsed >= 1 days) {
            return MAX_TX_STANDARD;
        }
        
        // During first 24 hours, use initial limit
        return MAX_TX_INITIAL;
    }
    
    // ================ ERC20 Overrides ================
    
    /**
     * @dev Override _transfer to implement charity fee and early-sell tax
     * @param sender Sender address
     * @param recipient Recipient address
     * @param amount Amount of tokens to transfer
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
        
        // Cache external state values to prevent multiple calls
        bool isPausedStateVar = adminManager.isPaused();
        bool isMaxTxLimitEnabledStateVar = adminManager.isMaxTxLimitEnabled();
        bool isTokenLaunchedStateVar = feeManager.isLaunched();
        bool isExcludedSenderVar = feeManager.isExcludedFromFee(sender);
        bool isExcludedRecipientVar = feeManager.isExcludedFromFee(recipient);
        address charityWalletVar = feeManager.getCharityWallet();
        
        // Reject transfers when paused, unless the sender has the OPERATOR_ROLE
        if (isPausedStateVar) {
            require(hasRole(OPERATOR_ROLE, msg.sender), "ERC20Pausable: transfers paused and caller is not an operator");
        }
        
        // Check for max transaction limit if enabled
        if (isMaxTxLimitEnabledStateVar && !isExcludedSenderVar && !isExcludedRecipientVar) {
            uint256 maxAmount;
            
            if (!isTokenLaunchedStateVar) {
                // If token is not launched yet, use initial limit
                maxAmount = MAX_TX_INITIAL;
            } else {
                // If more than 24 hours since launch, use higher limit
                uint256 timeElapsed = block.timestamp - feeManager.getLaunchTimestamp();
                if (timeElapsed >= 1 days) {
                    maxAmount = MAX_TX_STANDARD;
                } else {
                    maxAmount = MAX_TX_INITIAL;
                }
            }
            
            require(amount <= maxAmount, "Transfer amount exceeds the maximum allowed");
        }
        
        // EFFECTS - Calculate fees and process transfer
        
        // Skip fee calculation for excluded addresses or special transfers (mint/burn)
        if (sender == address(0) || recipient == address(0) || isExcludedSenderVar || isExcludedRecipientVar) {
            super._transfer(sender, recipient, amount);
            return;
        }
        
        // Calculate fees
        (uint256 charityFeeAmount, uint256 earlySellTaxAmount) = feeManager.calculateFees(sender, recipient, amount);
        uint256 transferAmount = amount - charityFeeAmount - earlySellTaxAmount;
        
        // INTERACTIONS - Execute transfers with fees if applicable
        
        // Execute main transfer with amount minus fees
        super._transfer(sender, recipient, transferAmount);
        
        if (charityFeeAmount > 0) {
            super._transfer(sender, charityWalletVar, charityFeeAmount);
            emit CharityFeeCollected(charityFeeAmount);
        }
        
        if (earlySellTaxAmount > 0) {
            super._transfer(sender, address(this), earlySellTaxAmount);
            emit EarlySellTaxCollected(sender, earlySellTaxAmount);
        }
        
        // INTERACTIONS - Make external calls after state changes
        if (!isTokenLaunchedStateVar) {
            // Set launch timestamp through fee manager
            feeManager.setLaunched(block.timestamp);
        }
        
        if (charityFeeAmount > 0) {
            // Record charity donation for tracking
            feeManager.addCharityDonation(charityFeeAmount);
        }
        
        if (earlySellTaxAmount > 0) {
            // Record early sell tax for tracking
            feeManager.addEarlySellTax(earlySellTaxAmount);
        }
    }
}
