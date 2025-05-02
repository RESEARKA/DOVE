// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IDOVE.sol";
import "./DOVEFees.sol";
import "./DOVEAdmin.sol";

/**
 * @title DOVE Token
 * @dev Implementation of the DOVE token with charity fee and early-sell tax mechanisms
 * 
 * IMPORTANT FEE STRUCTURE NOTICE:
 * This token implements two types of fees that affect transfer amounts:
 * 1. Charity Fee (0.5%): Applied to all transfers except excluded addresses
 *    - Fee is sent to a designated charity wallet
 * 2. Early Sell Tax (3% to 0%): Applied only when selling to DEX in first 72 hours
 *    - Tax rate decreases over time (3%, 2%, 1%, then 0%)
 *    - Tax amount is burned from supply
 * 
 * Users should be aware that the amount received by the recipient will be
 * less than the amount sent by the sender due to these fees.
 */
contract DOVE is ERC20Permit, ReentrancyGuard, IDOVE, AccessControl {
    
    // ================ Constants ================
    
    // Base supply: 100 billion tokens with 18 decimals
    uint256 private constant TOTAL_SUPPLY = 100_000_000_000 * 1e18;
    
    // Transaction limits
    uint256 private constant MAX_TX_INITIAL = TOTAL_SUPPLY * 2 / 1000; // 0.2%
    uint256 private constant MAX_TX_AFTER_24H = TOTAL_SUPPLY * 5 / 1000; // 0.5%
    
    // Charity fee percentage (0.5% = 50 basis points)
    uint16 private constant CHARITY_FEE = 50;
    
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
        
        // Register this contract as the authorized token address in the fee manager
        // This establishes the secure connection between the contracts
        feeManager.setTokenAddress(address(this));
        
        // Verify and lock the token address to prevent further changes
        // Calculate verification code using contract address and chain ID for extra security
        bytes32 verificationCode = keccak256(abi.encodePacked("VERIFY_TOKEN_ADDRESS", address(this), block.chainid));
        feeManager.verifyTokenAddress(verificationCode);
        
        // Transfer ownership of modules to token deployer with proper verification
        // Rigorous checking ensures that ownership transfers are completed successfully
        // We need to verify these transfers to ensure the deployer has full control
        address deployerAddress = msg.sender;
        
        // Transfer ownership of feeManager with verification
        try feeManager.transferOwnership(deployerAddress) {
            // Explicitly verify ownership was transferred correctly
            address newFeeOwner = feeManager.owner();
            require(newFeeOwner == deployerAddress, "Fee manager ownership transfer failed verification");
        } catch {
            // This should never happen with a newly deployed contract
            revert("Fee manager ownership transfer failed");
        }
        
        // Transfer ownership of adminManager with verification
        try adminManager.transferOwnership(deployerAddress) {
            // Explicitly verify ownership was transferred correctly
            address newAdminOwner = adminManager.owner();
            require(newAdminOwner == deployerAddress, "Admin manager ownership transfer failed verification");
        } catch {
            // This should never happen with a newly deployed contract
            revert("Admin manager ownership transfer failed");
        }
        
        // Mint total supply to deployer
        _mint(deployerAddress, TOTAL_SUPPLY);
        
        // Exclude owner, token contract, and charity wallet from fees
        feeManager._setExcludedFromFee(deployerAddress, true);
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
    
    /**
     * @dev Calculates the effective amount that will be received after applying fees
     * Useful for UI and user information purposes to show exact amounts
     * @param sender Address sending the tokens
     * @param recipient Address receiving the tokens
     * @param amount Amount of tokens to be sent
     * @return The effective amount that would be received after fees
     */
    function getEffectiveTransferAmount(address sender, address recipient, uint256 amount) external view returns (uint256) {
        // Skip fee calculation if amount is zero, excluded addresses, or mint/burn
        if (amount == 0 || 
            feeManager.isExcludedFromFee(sender) || 
            feeManager.isExcludedFromFee(recipient) ||
            sender == address(0) ||
            recipient == address(0)) {
            return amount;
        }
        
        // Calculate applicable fees
        uint16 charityFeePercent = feeManager.getCharityFee();
        uint16 earlySellTaxPercent = 0;
        
        // Add early sell tax if applicable (only on sells to DEX)
        if (feeManager.isEarlySellTaxEnabled() && feeManager.isKnownDex(recipient)) {
            earlySellTaxPercent = feeManager.getEarlySellTaxFor(sender);
        }
        
        // Calculate total fee percentage and amount
        uint16 totalFeePercent = charityFeePercent + earlySellTaxPercent;
        
        if (totalFeePercent == 0) {
            return amount;
        }
        
        uint256 feeAmount = amount * totalFeePercent / 10000;
        return amount - feeAmount;
    }
    
    // ================ Internal Functions ================
    
    /**
     * @dev Update internal balances for a transfer
     * @param sender Address sending the tokens
     * @param recipient Address receiving the tokens
     * @param amount Amount of tokens to transfer
     * @notice SECURITY: This function is strictly internal with no external calls to prevent reentrancy
     * WARNING: Do not add external calls to this function or any functions it calls
     * WARNING: Do not override this function in derived contracts with external calls
     */
    function _update(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        // SECURITY: This function must not make any external calls to prevent reentrancy
        // All external interaction must happen before or after _update is called
        
        // Skip pointless zero transfers to save gas
        if (amount == 0) {
            return;
        }
        
        // SECURITY: Explicit balance check for underflow protection
        // Even though Solidity 0.8+ has built-in overflow checking, this makes the check explicit
        // and provides a more descriptive error message
        require(sender == address(0) || _balances[sender] >= amount, "ERC20: transfer amount exceeds balance");
        
        // Update sender balance
        if (sender != address(0)) {
            _balances[sender] -= amount;
        }
        
        // Update recipient balance
        if (recipient != address(0)) {
            _balances[recipient] += amount;
        }
        
        // Emit transfer event
        emit Transfer(sender, recipient, amount);
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
        
        // Reject transfers when paused
        require(!adminManager.paused(), "ERC20Pausable: token transfer while paused");
        
        // Check for max transaction limit if enabled
        if (adminManager.isMaxTxLimitEnabled() && !feeManager.isExcludedFromFee(sender) && !feeManager.isExcludedFromFee(recipient)) {
            require(amount <= _maxTxAmount, "DOVE: Transfer amount exceeds the maximum allowed");
        }
        
        // ===== FEES CALCULATION - Load all state variables first =====
        
        // SECURITY: Load all necessary state variables for fee calculation into memory
        // before any state changes to avoid potential reentrancy or inconsistent state
        bool isExcludedSender = feeManager.isExcludedFromFee(sender);
        bool isExcludedRecipient = feeManager.isExcludedFromFee(recipient);
        bool isDexRecipient = feeManager.isKnownDex(recipient);
        address charityWallet = feeManager.charityWallet();
        
        // Calculate fees using pure function with no state changes
        (uint256 charityFeeAmount, uint256 earlySellTaxAmount) = feeManager.calculateFees(
            sender,
            recipient,
            amount
        );
        
        // Calculate final transfer amount after all fees
        uint256 transferAmount = amount - charityFeeAmount - earlySellTaxAmount;
        
        // ===== EFFECTS - Update all balances using the internal _update function =====
        
        // SECURITY: _update is a pure internal function with no external calls 
        // It only updates balances and emits events - it cannot reenter
        
        // First transfer the main amount to recipient
        _update(sender, recipient, transferAmount);
        
        // Then handle fees by transferring to respective wallets if applicable
        if (charityFeeAmount > 0) {
            _update(sender, charityWallet, charityFeeAmount);
        }
        
        if (earlySellTaxAmount > 0) {
            // Burn the early sell tax by transferring to address(0)
            _update(sender, address(0), earlySellTaxAmount);
        }
        
        // ===== INTERACTIONS - Only after all state changes are complete =====
        
        // SECURITY: All external calls come last, after all state changes
        
        // Update charity donation tracking
        if (charityFeeAmount > 0) {
            feeManager.addCharityDonation(charityFeeAmount);
        }
        
        // Update token acquisition timestamps for early-sell tax calculation
        if (transferAmount > 0 && !isExcludedRecipient && !isDexRecipient) {
            feeManager.updateAcquisitionTimestamp(recipient);
        }
    }
}
